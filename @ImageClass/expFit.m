% ImageClass function
function expFit(self,vec,x,str)
%expFit performs a linear fit to exponential data of the form: y = Ae^(bx)
% Parameter maps of A and b are appended to the image matrix
% The parameter solution equations were acquired from
% http://mathworld.wolfram.com/LeastSquaresFittingExponential.html.

if self.check
    d = self.dims(1:3);
    nx = self.dims(4);
    if nargin==1
        prompt = {'Type of data to fit (T1,T1ir,T2,ADC,gen):',...
                  'Images to use in fit:',...
                  'x-values:'};
        answer = inputdlg(prompt,'Linear Fit',1,...
                            {'gen',num2str(1:nx),num2str(1:nx)});
        str = answer{1};
        vec = str2num(answer{2});
        x = str2num(answer{3});
    end
    if (nargin==3)
        str = 'gen';
    end
        
    if (length(x)==nx) && all(ismember(vec,1:nx)) && (length(vec)==nx)
        % Initialize the data:
        dd = prod(d);
        x = x(:);
        y = reshape(self.mat(:,:,:,vec),[dd,nx]);
        if strcmp(str,'T1ir')
            % Assumes fitting magnitude IR images
            % Model: y = |A + B*exp(-x/b)|, where b = T1
            % Uses functions written by J. Barral et al., 2009 (Stanford)
            % Initialize required parameter structure:
            nlsS.tVec = x;
            nlsS.N = nx;
            nlsS.T1Start = 1;
            nlsS.T1Stop = 5000;
            nlsS.T1Vec = (nlsS.T1Start:nlsS.T1Stop)';
            nlsS.T1Len = nlsS.T1Stop;
            nlsS.nlsAlg = 'grid';
            nlsS.nbrOfZoom = 1;
            nlsS.T1LenZ = 0;
            alph = 1./nlsS.T1Vec;
            nlsS.theExp = exp( -nlsS.tVec*alph' );
            nlsS.rhoNormVec = sum( nlsS.theExp.^2,1)' ...
                - ((sum(nlsS.theExp,1)').^2)/nlsS.N;
            
            % Use mask, otherwise will take too long
            mask = self.mask.mat;
            if isempty(mask)
                alph = 0.1;
                mask = max(self.mat(:,:,:,vec),[],4);
                mask = mask > (alph * max(self.valExt(:,2)));
                for i = 1:d(3)
                    mask(:,:,i) = medfilt2(mask(:,:,i),[3,3]);
                end
            end
            mask = find(mask);
            nm = length(mask);
            
            % Loop over each voxel fit:
            b = zeros(dd,1); B = b; A = b; R = b;
            np = size(y,1);
            hw = waitbar(0,'Calculating fits ...');
            for i = 1:nm
                ii = mask(i);
                [b(ii),B(ii),A(ii),R(ii)] = rdNlsPr(y(ii,:), nlsS);
                waitbar(i/np,hw);
            end
            delete(hw);
            
            % Find nonsense results:
            ind = ~(isfinite(A) & isfinite(B) & isfinite(b) & isfinite(R) & (b>0));
            A(ind) = 0;
            B(ind) = 0;
            b(ind) = 0;
            R(ind) = 0;
            
        else
            % Fit data to y = A*exp(-b*x)
            yy = y.*log(y);
            den = sum(y,2) .* (y*x.^2) - (y*x).^2;
            A = exp(((y*x.^2) .* sum(yy,2) - (y*x) .* (yy*x)) ./ den);
            b = -(sum(y,2) .* (yy*x) - (y*x) .* sum(yy,2)) ./ den;
            clear den yy

            y = log(y);
            R = ((y*x) - nx*mean(x)*mean(y,2)).^2 ./ ...
                ((sum(x.^2) - nx*mean(x)^2) * (sum(y.^2,2) - nx*mean(y,2).^2));

            if any(strcmp(str,{'T1','T2'}))
                b = 1./b;
            end
            if strcmp(str,'gen')
                str = 'k';
            end

            % Find nonsense results:
            ind = ~(isfinite(A) & isfinite(b) & isfinite(R) & (A>0) & (b>0));
            A(ind) = 0;
            b(ind) = 0;
            R(ind) = 0;
            
        end

        % Update object properties
        self.mat = cat(4,self.mat(:,:,:,1),...
                         reshape(A,d),...
                         reshape(b,d),...
                         reshape(R,d));
        self.valExt = [squeeze(min(min(min(self.mat,[],3),[],2),[],1)),...
                       squeeze(max(max(max(self.mat,[],3),[],2),[],1))];
        self.labels = {'Img1','So',str,'GoF'};
        self.scaleM = [self.scaleM(1),ones(1,3)];
        self.scaleB = [self.scaleB(1),zeros(1,3)];
        self.thresh = [self.thresh(1,:);ones(3,1)*[-inf,inf]];
        self.dims(4) = 4;
    end
end





