%
function [fimg,labels] = minkowskiFun(img,n,thresh,mask)
% Calculates regional minkowski functionals using a moving window method
% Inputs:
%   img     = 3D image matrix
%   n       = moving window radius
%   thresh  = thresholds for converting image to binary
%   mask    = binary image mask for VOI
% Output: fimg = 4D minkowski functional maps 
%                   OR [#thresh x nMF] matrix of results for global values
%           * 2D : Area, Perimeter, Euler-Poincare
%           * 3D : Volume, Surface Area, Mean Breadth, Euler-Poincare
%         labels = cell array of MF names

fimg = []; labels = {};
if nargin<2
    n = [3,3];
end
if (nargin<3) || isempty(thresh)
    % Determine image scaling:
    % Top/bottom 5% quantiles
    scl = quantile(img(:),[0.2,0.95]);
    thresh = linspace(scl(1),scl(2),11);
end
nth = length(thresh);

nD = nnz(n);
if ismember(nD,[2,3]);
    [d(1),d(2),d(3),~] = size(img);
    if nD==2
        disp('Performing 2D Minkowski Functional Analysis');
        labels = {'Area','Perimeter','Euler'};
        nmf = 3;
        n(3) = 0;
        p4 = [];
    else
        disp('Performing 3D Minkowski Functional Analysis');
        labels = {'Volume','SurfaceArea','Mean Breadth','Euler'};
        nmf = 4;
    end
    if any(isinf(n))
        % Perform analysis on entire image
        disp('Performing global analysis');
        if (nargin<4) || all(d(1:3)~=size(mask))
            mask = true(d);
        end
        fimg = zeros(nth,nmf);
        parfor ti = 1:nth
            BW = (img > thresh(ti)) & mask;
            if nD == 2
                fimg(ti,:) = [imAreaDensity(BW),...
                              imPerimeterDensity(BW),...
                              imEuler2dDensity(BW)];
            elseif nD == 3
                fimg(ti,:) = [imVolumeDensity(BW),...
                              imSurfaceDensity(BW),...
                              imMeanBreadth(BW),...
                              imEuler3dDensity(BW)];
            end
        end
    else
        % Perform analysis on moving window
        disp(['Performing local analysis [',num2str(n),']']);
        if (nargin<4) || all(d(1:3)~=size(mask))
            ind = 1:prod(d(1:3));
        else
            ind = find(mask);
        end
        ntot = length(ind);
        disp(['Number of iterations: ',num2str(ntot)])

        fimg = zeros([d,nth,nmf]);
        hw = waitbar(0,'Calculating local Minkowski Functionals ...');
        t = tic;
        for i = 1:ntot
            if mod(i,10000)==0
                disp(['  ',num2str(ntot-i),' left (',...
                      datestr(toc(t)*(ntot-i)/(i*60*60*24),'DD:HH:MM:SS'),')'])
            end
            [ii,jj,kk] = ind2sub(d(1:3),ind(i));
            timg = img(max(1,ii-n(1)):min(d(1),ii+n(1)),...
                       max(1,jj-n(2)):min(d(2),jj+n(2)),...
                       max(1,kk-n(3)):min(d(3),kk+n(3)));
            parfor ti = 1:nth
                BW = timg > thresh(ti);
                if nD == 2
                    p1(ti) = imAreaDensity(BW);
                    p2(ti) = imPerimeterDensity(BW);
                    p3(ti) = imEuler2dDensity(BW);
                elseif nD == 3
                    p1(ti) = imVolumeDensity(BW);
                    p2(ti) = imSurfaceDensity(BW);
                    p3(ti) = imMeanBreadth(BW);
                    p4(ti) = imEuler3dDensity(BW);
                end
            end
            fimg(ii,jj,kk,:,:) = reshape([p1(:),p2(:),p3(:),p4(:)],[1,1,1,nth,nD+1]);
            waitbar(i/ntot,hw,['Calculating local Minkowski Functional: ',...
                                num2str(i),'/',num2str(ntot)]);
        end
        delete(hw);
        toc(t);
    end
end
