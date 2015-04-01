function B = ordfilt3(A,varargin)

%ORDFILT3 1-D, 2-D and 3-D median filtering.
%   B = ORDFILT3(A,[M N P]) performs median filtering of the 3-D array A.
%   Each output pixel contains the median value in the M-by-N-by-P
%   neighborhood around the corresponding pixel in the input array.
%
%   B = ORDFILT3(A,[M N]) performs median filtering of the matrix A. Each
%   output pixel contains the median value in the M-by-N neighborhood
%   around the corresponding pixel.
%
%   B = ORDFILT3(A,M) performs median filtering of the vector A. Each
%   output pixel contains the median value in the M neighborhood
%   around the corresponding pixel.
%
%   B = ORDFILT3(A) performs median filtering using a 3 or 3x3 or 3x3x3
%   neighborhood according to the size of A.
%
%   B = ORDFILT3(A,...,PADOPT) pads array A using PADOPT option:
%
%      String values for PADOPT (default = 'replicate'):
%      'circular'    Pads with circular repetition of elements.
%      'replicate'   Repeats border elements of A. (DEFAULT)
%      'symmetric'   Pads array with mirror reflections of itself.
%
%      If PADOPT is a scalar, A is padded with this scalar.
%
%   Class Support
%   -------------
%     Input array can be numeric or logical. The returned array is of class
%     single or double.
%
%   Notes
%   -----
%     M, N and P must be odd integers. If not, they are incremented by 1.
%
%     If NANMEDIAN exists (Statistics Toolbox is required), then ORDFILT3
%     treats NaNs as missing values.
%
%     If you work with very large 3D arrays, an "Out of memory" error may
%     appear. The chunk factor (CHUNKFACTOR, default value = 1) must be
%     increased to reduce the size of the chunks. This will imply more
%     iterations whose number is directly proportional to CHUNKFACTOR. Use
%     the following syntax: ORDFILT3(A,[...],PADOPT,CHUNKFACTOR)
%
%   Examples
%   --------
%     %>> 1-D median filtering <<
%     t = linspace(0,2*pi,100);
%     y = cos(t);
%     I = round(rand(1,5)*99+1);
%     y(I) = rand(size(I));
%     ys = ordfilt3(y,5);
%     plot(t,y,':',t,ys)
%
%     %>> 2-D median filtering <<
%     % original image
%     I = imread('eight.tif');
%     % noisy image
%     J = I;
%     rand('state',sum(100*clock))
%     J(rand(size(J))<0.01) = 255;
%     J(rand(size(J))<0.01) = 0;
%     % denoised image
%     K = ordfilt3(J);
%     % figures
%     figure
%     subplot(121),imshow(J), subplot(122), imshow(K)
%
%     %>> 3-D median filtering <<
%     rand('state',0)
%     [x,y,z,V] = flow(50);
%     noisyV = V + 0.1*double(rand(size(V))>0.95);
%     clear V
%     figure
%     subplot(121)
%     hpatch = patch(isosurface(x,y,z,noisyV,0));
%     isonormals(x,y,z,noisyV,hpatch)
%     set(hpatch,'FaceColor','red','EdgeColor','none')
%     daspect([1,4,4]), view([-65,20]), axis tight off
%     camlight left; lighting phong 
%     subplot(122)
%     %--------
%     denoisedV = ordfilt3(noisyV,7);
%     %--------
%     hpatch = patch(isosurface(x,y,z,denoisedV,0));
%     isonormals(x,y,z,denoisedV,hpatch)
%     set(hpatch,'FaceColor','red','EdgeColor','none')
%     daspect([1,4,4]), view([-65,20]), axis tight off
%     camlight left; lighting phong
%       
%   See also MEDFILT1, MEDFILT2, HMF.
%
%   -- Damien Garcia -- 2007/08, revised 2010/04
%   website: <a
%   href="matlab:web('http://www.biomecardio.com')">www.BiomeCardio.com</a>

%% Note:
% If you work with large 3D arrays, an "Out of memory" error may appear.
% The chunk factor thus must be increased to reduce the size of the chunks.

%% Checking input arguments
if isscalar(A), B = A; return, end
if all(isnan(A(:))), B = A; return, end
if (nargin>1) && isnumeric(varargin{1})
    varargin = [{'Size'},varargin];
end
p = inputParser;
addRequired(p,'A',@(x)ndims(x)<4);
addParamValue(p,'Size',3*ones(1,ndims(A)),@isvector);
addParamValue(p,'Type','median',@(x)ismember(x,{'median','max','min'}));
addParamValue(p,'Pad','replicate',@(x)ismember(x,{'circular','symmetric','replicate'}));
addParamValue(p,'Chunks',1,@(x)isscalar(x)&&(x>=1));
addParamValue(p,'Shape','box',@(x)ismember(x,{'box','circular'}));
parse(p,A,varargin{:})
ftype = p.Results.Type;
siz = p.Results.Size;
padopt = p.Results.Pad;
CHUNKFACTOR = round(p.Results.Chunks);
fshape = p.Results.Shape;

%% Make SIZ a 3-element array
sizA = size(A);
if numel(siz)==2
    siz = [siz 0];
elseif isscalar(siz)
    if sizA(1)==1
        siz = [0 siz 0];
    else
        siz = [siz 0 0];
    end
end

%% Create logical kernel
% siz = ceil((siz-1)/2);
k = cmi_kmask(siz,fshape);

%% Chunks: the numerical process is split up in order to avoid large arrays
N = numel(A);
% siz = ceil((siz-1)/2);
% n = prod(siz*2+1);
n = nnz(k);
if n==1, B = A; return, end
nchunk = (1:ceil(N/n/CHUNKFACTOR):N);
if nchunk(end)~=N, nchunk = [nchunk N]; end

%% Change to double if needed
class0 = class(A);
if ~isa(A,'float')
    A = double(A);
end

%% Padding along specified direction
% If PADARRAY exists (Image Processing Toolbox), this function is used.
% Otherwise the array is padded with scalars.
B = A;
sizB = sizA;
try
    A = padarray(A,siz,padopt);
catch
    if ~isscalar(padopt)
        padopt = 0;
        warning('MATLAB:ordfilt3:InexistentPadarrayFunction',...
            ['PADARRAY function does not exist: '...
            'only scalar padding option is available.\n'...
            'If not specified, the scalar 0 is used as default.']);
    end
    A = ones(sizB+siz(1:ndims(B))*2)*padopt;
    A(siz(1)+1:end-siz(1),siz(2)+1:end-siz(2),siz(3)+1:end-siz(3)) = B;
end
sizA = size(A);

if numel(sizB)==2
    sizA = [sizA 1];
    sizB = [sizB 1];
end

%% Creating the index arrays (INT32)
inc = zeros([1,3,n],'int32');
[inc(1,1,:),inc(1,2,:),inc(1,3,:)] = ind2sub(2*siz+1,find(k));
inc = bsxfun(@minus,inc,int32(siz+1));
% inc = zeros([3 2*siz+1],'int32');
% siz = int32(siz);
% [inc(1,:,:,:),inc(2,:,:,:),inc(3,:,:,:)] = ndgrid(...
%     [0:-1:-siz(1) 1:siz(1)],...
%     [0:-1:-siz(2) 1:siz(2)],...
%     [0:-1:-siz(3) 1:siz(3)]);
% inc = reshape(inc,1,3,[]);
I = zeros([sizB 3],'int32');
sizB = int32(sizB);
[I(:,:,:,1),I(:,:,:,2),I(:,:,:,3)] = ndgrid(...
    (1:sizB(1))+siz(1),...
    (1:sizB(2))+siz(2),...
    (1:sizB(3))+siz(3));
I = reshape(I,[],3);

%% Set function call:
if ~strcmp(ftype,'median')
    ins = {[],2};
else
    ins = {2};
end
if exist(['nan',ftype],'file')
    ftype = ['nan',ftype];
end

%% Filtering
for i = 1:length(nchunk)-1

    Im = repmat(I(nchunk(i):nchunk(i+1)-1,:),[1 1 n]);
    Im = bsxfun(@plus,Im,inc);

    I0 = Im(:,1,:) +...
        (Im(:,2,:)-1)*sizA(1) +...
        (Im(:,3,:)-1)*sizA(1)*sizA(2);
    I0 = squeeze(I0);
    B((nchunk(i):nchunk(i+1)-1)) = feval(ftype,A(I0),ins{:});
%     if existNaNmedian
%         B(nchunk(i):nchunk(i+1)) = nanmedian(A(I0),2);
%     else
%         B(nchunk(i):nchunk(i+1)) = median(A(I0),2);
%     end
end
B = cast(B,class0);
    
