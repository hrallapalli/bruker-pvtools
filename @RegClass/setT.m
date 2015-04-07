% RegClass function
function setT(self,hObject,~)
% Manually set affine matrix values using edit boxes in GUI

i = find(strcmp(hObject.Tag(end-1:end),...
    {'11','21','31','12','22','32','13','23','33','t1','t2','t3'}),1);
% Adjust for additional 4th row ([0 0 0 1])
i = i+(i-mod(i-1,3)-1)/3;
if isempty(i)
    error('Invalid input object')
end
val = str2double(hObject.String);
M = eye(4);
if ~(isempty(val) || isnan(val))
    if isempty(self.elxObj.Tx0)
        M = eye(4);
    else
        M = self.par2affine(self.elxObj.Tx0.TransformParameters);
    end
    hObject.String = num2str(val);
    M(i) = val;
    A = M(1:3,1:3)';
    T = M(1:3,4);
    self.elxObj.setTx0([A(:)',T'],...
                       self.cmiObj(1).img.voxsz,...
                       self.cmiObj(1).img.dims(1:3),...
                       'DefaultPixelValue',self.defVal);
    self.setTchk(true);
else
    if ~isempty(self.elxObj.Tx0) && strncmp(self.elxObj.Tx0.Transform,'Affine',6)
        M = [reshape(self.elxObj.Tx0.TransformParameters(1:9),3,3),...
             self.elxObj.Tx0.TransformParameters(10:12)'];
    end
    hObject.String = num2str(M(i));
end
