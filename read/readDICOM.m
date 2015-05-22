function [img,label,fov,dcmdata] = readDICOM(varargin)

fnames = varargin{1};
din = [];
if nargin==2
    din = varargin{2};
end
img = []; label = {}; fov = [];
[path,fname,ext] = fileparts(fnames);
if ~any(strcmp(ext,{'.dcm','.1'}))
    ext = [];
end

% Find and load all DICOM files in selected directory
if strcmpi(fname,'dicomdir')
    % DICOM names are stored in "DICOMDIR" file
    hp = waitbar(0,'Reading DICOMDIR ...');
    tinfo = dicominfo(fnames);
    fnames = fieldnames(tinfo.DirectoryRecordSequence);
    nf = length(fnames);
    ind = false(1,nf);
    for i = 1:nf
        if isfield(tinfo.DirectoryRecordSequence.(fnames{i}),'ReferencedFileID')
            tdir = tinfo.DirectoryRecordSequence.(fnames{i}).ReferencedFileID;
            fnames{i} = strrep(tdir,'\',filesep);
        else
            ind(i) = true;
        end
        waitbar(i/nf,hp,'Finding file locations ...');
    end
    delete(hp);
    fnames(ind) = [];
    nf = nf - nnz(ind);
else
    % All DICOMs are in single directory
    fnames = dir([path,filesep,'*',ext]);
    fnames = {fnames(:).name};
    fnames(~cellfun(@(x)(exist(x,'file')==2)&&isdicom(x),fnames)) = [];
%     fnames = fnames(isDICOM(fullfile(path,fnames))==1);
    nf = length(fnames);
end

dcmdata = struct('SeriesInstanceUID',{},... % for sorting multiple images
                 'img',{},...
                 'AcqN',{},...
                 'SlcLoc',{},...
                 'SlcThk',{},...
                 'PixelSpacing',{},...
                 'StudyDescription',{},...
                 'PatientID',{},...
                 'Label',{});
% * Images are sorted into 3D via SlcLoc,
%   and 4D via arrayed values:
%       MRI - TE, TR, ...
%       CT  - kV, ...
             
% Read in all DICOM slices:
hp = waitbar(0,'','WindowStyle','modal',...
    'CreateCancelBtn','setappdata(gcbf,''canceling'',1)'); % Option to cancel load midway
setappdata(hp,'canceling',0)
for ifn = 1:nf
    
    % Check for Cancel button press
    if getappdata(hp,'canceling')
        img = []; label = {}; fov = [];
        break
    end
    waitbar((ifn-1)/nf,hp,fnames{ifn});
    
    % Load DICOM file info:
    tinfo = dicominfo(fullfile(path,fnames{ifn}));
    
    % Check if Series already exists in structure:
%     disp(tinfo.SeriesInstanceUID);
%     disp(num2str(tinfo.SeriesNumber));
%     disp(num2str(tinfo.InstanceNumber));
    j = strcmp(tinfo.SeriesInstanceUID,{dcmdata(:).SeriesInstanceUID});
    if isfield(tinfo,'AcquisitionNumber') && ~isempty(tinfo.AcquisitionNumber) ...
            && ~isempty(dcmdata)
        j = j & (tinfo.AcquisitionNumber==[dcmdata(:).AcqN]);
    end
    j = find(j,1);
    if isempty(j)
        % Initialize new series in structure:
        j = length(dcmdata)+1;
        val = '';
        if isfield(tinfo,'SeriesInstanceUID')
            val = tinfo.SeriesInstanceUID;
        end
        dcmdata(j).SeriesInstanceUID = val;
        if isfield(tinfo,'AcquisitionNumber')
            dcmdata(j).AcqN = tinfo.AcquisitionNumber;
        else
            dcmdata(j).AcqN = 1;
        end
        val = [1,1];
        if isfield(tinfo,'PixelSpacing')
            val = tinfo.PixelSpacing;
        end
        dcmdata(j).PixelSpacing = val;
        val = [];
        if isfield(tinfo,'SliceThickness')
            val = tinfo.SliceThickness;
        elseif isfield(tinfo,'SpacingBetweenSlices')
            val = tinfo.SpacingBetweenSlices;
        end
        dcmdata(j).SlcThk = val;
        val = '';
        if isfield(tinfo,'StudyDescription')
            val = tinfo.StudyDescription;
        end
        dcmdata(j).StudyDescription = val;
        if isfield(tinfo,'SeriesDescription') && ~isempty(tinfo.SeriesDescription)
            val = tinfo.SeriesDescription;
        elseif isfield(tinfo,'ProtocolName') && ~isempty(tinfo.ProtocolName)
            val = tinfo.ProtocolName;
        else val = tinfo.Modality;
        end
        dcmdata(j).Label = {val};
        dcmdata(j).SlcLoc = [];
        val = '';
        if isfield(tinfo,'PatientID')
            val = tinfo.PatientID;
        end
        dcmdata(j).PatientID = val;
        dcmdata(j).img = [];
    end
    k = length(dcmdata(j).SlcLoc)+1;
    if isfield(tinfo,'SliceLocation')
        val = tinfo.SliceLocation;
    elseif isfield(tinfo,'ImagePositionPatient')
        val = tinfo.ImagePositionPatient;
    end
    dcmdata(j).SlcLoc(k,1) = val(end);
    if isfield(tinfo,'EchoTime')
        if ~isempty(tinfo.EchoTime)
            dcmdata(j).TE(k) = tinfo.EchoTime;
        end
    end
    if isfield(tinfo,'RepetitionTime')
        if ~isempty(tinfo.RepetitionTime)
            dcmdata(j).TR(k) = tinfo.RepetitionTime;
        end
    end
    
    % Read slice data from file:
    if isfield(tinfo,'RescaleSlope')
        ySlope = tinfo.RescaleSlope;
    else ySlope = 1;
    end
    if isfield(tinfo,'RescaleIntercept')
        yInt = tinfo.RescaleIntercept;
    else yInt = 0;
    end
    timg = ySlope * double(dicomread(tinfo)) + yInt;
    dcmdata(j).img(:,:,k) = timg;
end
delete(hp);
% Sort by slice location
for i = 1:length(dcmdata)
    [dcmdata(i).SlcLoc,ix] = sort(dcmdata(i).SlcLoc);
    dcmdata(i).img = dcmdata(i).img(:,:,ix);
end

n = length(dcmdata);
gflag = 0;
oimg = [];
if (n==1) && (length(unique(round(diff(dcmdata.SlcLoc),4)))==2)
% Case for 2-slice gapped CT data
    oimg = dcmdata.img;
    oloc = dcmdata.SlcLoc;
    gflag = 2;
elseif all(ismember(cellfun(@length,{dcmdata(:).SlcLoc}),1:2))
% 1: Case for single-slice gapped CT data
% 2: Case for 2-slice gapped CT data
    gflag = all(ismember(cellfun(@length,{dcmdata(:).SlcLoc}),1:2));
    oimg = cat(3,dcmdata(:).img);
    oloc = cat(1,dcmdata(:).SlcLoc);
end
if gflag
    answer = questdlg('How would you like to compile these slices?',...
        'Gapped CT','Concatenate','Insert Gaps','Cancel','Concatenate');
    if ~strcmp(answer,'Cancel')
        tdata = dcmdata(1);
        if strcmp(answer,'Insert Gaps')
            fval = str2double(inputdlg('Blank Slice Value:','',1,{'-1024'}));
        % Determine gaps:
            [locs,ix] = sort(oloc);
            d = size(oimg);
            if gflag == 2
                dnew = floor((locs(3)-locs(1))/(locs(2)-locs(1)));
                dz = abs(locs(3)-locs(1))/dnew;
                d(3) = d(3)*dnew/2;
                tmat = ones(d)*fval;
                ind = round(dnew/2):dnew:d(3);
                ind = [ind;ind+1];
            else % Single-slice
                dnew = floor((locs(2)-locs(1))/tdata.SlcThk);
                dz = abs(locs(2)-locs(1))/dnew;
                d(3) = d(3)*dnew;
                tmat = ones(d)*fval;
                ind = round(dnew/2):dnew:d(3);
            end
            disp(['Image slices are now: ',num2str(ind(:)')])
            tmat(:,:,ind(:)) = oimg(:,:,ix);
            tdata.SlcLoc = (1:d(3))'*dz + locs(1) - round(dnew/2)*dz;
            tdata.SlcThk = abs(diff(tdata.SlcLoc(1:2)));
            tdata.img = tmat;
        else
            tdata.img = oimg;
            tdata.SlcLoc = oloc;
        end
        dcmdata = tdata;
    end
end
    
% User GUI to select single acquisition from set:
if length(dcmdata)>1
    str = strcat('(',cellfun(@(x)num2str(length(x)),{dcmdata(:).SlcLoc},...
                             'UniformOutput',false),...
                 ' Slices)',[dcmdata(:).Label]);
    answer = listdlg('ListString',str,'SelectionMode','single',...
                     'ListSize',[300,300]);
    if isempty(answer)
        return % User cancelled the load
    else
        dcmdata = dcmdata(answer);
    end
end

ind = isnan(dcmdata.SlcLoc);
dcmdata.img(:,:,ind) = [];
dcmdata.SlcLoc(ind) = [];

% Sort slices by location:
uind = [];
n4d = 1;
if all(isfield(dcmdata,{'TR','TE'}))
    [C,~,uind] = unique([dcmdata.TR',dcmdata.TE'],'rows');
    n4d = size(C,1);
end
uind = [uind,dcmdata.SlcLoc];
[~,ix,~] = unique([uind,dcmdata.SlcLoc],'rows');
ns = length(ix);
[d(1),d(2),d(3)] = size(dcmdata.img);
if ns~=d(3)
    % MR Solutions DICOMs have no way to separate out b-values of DWI
    if mod(d(3),ns)==0
        n4d =  d(3)/ns;
        uind = repmat(1:n4d,ns,1);
        uind = uind(:);
        ix = repmat(ix,n4d,1);
    else
        error('Matrix cannot be separated into 4D.')
    end
end
if (n4d>1) && (d(3)==(n4d*nnz(uind==1)))
    ns = d(3)/n4d;
    dcmdata.img = reshape(dcmdata.img(:,:,ix),[d(1:2),ns,n4d]);
    dcmdata.SlcLoc = dcmdata.SlcLoc(ix(1:ns));
    % Determine labeling:
    dcmdata.Label = cell(1,n4d);
    ind = ix(1:ns:d(3));
    if isfield(dcmdata,'TR') && length(unique(dcmdata.TR))>1
        dcmdata.Label = strcat(dcmdata.Label,'TR=',...
            cellfun(@num2str,num2cell(dcmdata.TR(ind)),...
                    'UniformOutput',false),'; ');
    end
    if isfield(dcmdata,'TE') && length(unique(dcmdata.TE))>1
        dcmdata.Label = strcat(dcmdata.Label,'TE=',...
            cellfun(@num2str,num2cell(dcmdata.TE(ind)),...
                    'UniformOutput',false),'; ');
    end
    ind = cellfun(@isempty,dcmdata.Label);
    if any(ind)
        dcmdata.Label(ind) = cellfun(@num2str,num2cell(find(ind)));
        dcmdata.Label = cellfun(@num2str,num2cell(1:n4d),...
                                'UniformOutput',false);
    end
end

% if all(n==n(1)) % (all slice locations replicated the same number of times)
%         dcmdata.img = reshape(dcmdata.img,[d(1:2),d(3)/n(1),n(1)]);
% end
% if isfield(tinfo,'SequenceName') && strncmp(tinfo.SequenceName,'MGE',3)
%     nz = nnz(dcmdata.SlcLoc==dcmdata.SlcLoc(1));
%     ns = d(3)/nz;
%     dcmdata.img = reshape(dcmdata.img(:,:,ix),[d(1:2),ns,nz]);
% else
%     % MR Solutions DICOMs aren't separated with AcquisitionNumber:
%     n = zeros(1,length(ix));
%     for i = 1:length(ix)
%         n(i) = nnz(ic==ix(i));
%     end
%     if all(n==n(1))
%         dcmdata.img = reshape(dcmdata.img,[d(1:2),d(3)/n(1),n(1)]);
%         dcmdata.Label = repmat(dcmdata.Label,1,n(1));
%     end
%     dcmdata.img = dcmdata.img(:,:,ix,:);
%     dcmdata.SlcLoc = dcmdata.SlcLoc(ix);
% end

% Check for dimension match
[d(1),d(2),d(3),d(4)] = size(dcmdata.img);
if ~isempty(din) && ~all(d(1:3)==din)
    error(['Dimensions must match!',sprintf(' %f',d)])
end

% Prepare data to return:
img = dcmdata.img;
dcmdata = rmfield(dcmdata,'img');
[d(1),d(2),d(3),d(4)] = size(img);
fov = [fliplr(dcmdata.PixelSpacing(:)'),1] .* d(1:3);
if length(dcmdata.SlcLoc)>1
    fov(3) = abs(diff(dcmdata.SlcLoc([1,end]))) * d(3)/(d(3)-1);
elseif ~isempty(dcmdata.SlcThk)
    fov(3) = d(3) * dcmdata.SlcThk;
end
label = dcmdata.Label;
