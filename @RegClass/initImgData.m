% RegClass function
function initImgData(self,varargin)

tObj = varargin{1};
i = (tObj.h.mainFig==self.cmiObj(2).h.mainFig)+1;
self.points{i} = [];
% Delete any exist point plots associated with image:
if ~isnan(self.hpts(i)) && ishandle(self.hpts(i))
    delete(self.hpts(i))
end
% If Homologous image was loaded, reset output director based on name
if (i==2)
    tdir = fileparts(self.odir);
    nname = self.cmiObj(2).img.name;
    ndir = self.cmiObj(2).img.dir;
    if ~isempty(nname)
        tname = nname;
    else
        tname = 'Unknown';
    end
    if ~isempty(ndir)
        tdir = ndir;
    end
    self.setOdir(fullfile(tdir,['elxreg_',tname,filesep]));
    set(self.h.checkbox_useExistingT,'Enable','off','Value',0);
    self.elxObj.setTx0; % Initializes the transform
    
    % Update GUI objects:
    set(self.h.checkbox_useExistingT,'Value',0,'Enable','off');
    set([self.h.edit_a11,self.h.edit_a12,self.h.edit_a13,...
         self.h.edit_a21,self.h.edit_a22,self.h.edit_a23,...
         self.h.edit_a31,self.h.edit_a32,self.h.edit_a33,...
         self.h.edit_t1,self.h.edit_t2,self.h.edit_t3],'Enable','off');
    
end