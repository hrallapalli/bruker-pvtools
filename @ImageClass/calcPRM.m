% ImageClass function
% Calculate PRM
function [labels,vals] = calcPRM(self,vec)
labels = {}; vals = [];
% Make sure image and mask are available
if self.check && self.mask.check
    if (nargin == 2) && isnumeric(vec)
        
        % extract mask coordinates
        mskind = find(self.mask.mat);
        np = numel(mskind);
        
        % determine what images need to be passed in
        tvec = self.prm.dvec;
        tvec(tvec==0) = vec;
        tvec = unique(tvec);
        nv = length(tvec);
        
        % CJG 20151103: Apply Wiener2([3 3]) Filter to data
        if self.prm.normchk
            imag_temp=self.mat;
            hing = waitbar(0,'Wiener2 Filter ...');
            for j= 1:size(self.mat,3)
                waitbar(j/size(self.mat,3),hing)
                imag_temp(:,:,j,1)=wiener2(imag_temp(:,:,j,1),[3 3]);
                imag_temp(:,:,j,2)=wiener2(imag_temp(:,:,j,2),[3 3]);
            end
            close(hing);
        else
            imag_temp=self.mat;
        end
        
        % extract image values
        vals = zeros(np,nv);
        for i = 1:nv
            vals(:,i) = imag_temp(mskind + (tvec(i)-1)*(prod(self.dims(1:3)))); % Added in by CJG 20151103
%             vals(:,i) = self.mat(mskind +
%             (tvec(i)-1)*(prod(self.dims(1:3)))); %commented out by CJG
%             20151103
        end
        clear imag_temp

        % Finally, calculate the PRM
        [labels,vals] = self.prm.calcPRM(vals,tvec,vec,self.labels(tvec),self.mask.mat);
    end
end