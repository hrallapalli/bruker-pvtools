% CMIclass function
function GUIupdate(self,varargin)
% Updates CMI GUI objects with current properties/limits
opts = {'4D','slc','view','clim'};

if self.guicheck
    
    viewUDchk = false;
    cslc = self.slc(self.orient);
    td = self.img.dims([self.orient,4]);
    
    % Determine which objects to update:
    if (nargin>1) && iscellstr(varargin) && all(ismember(varargin,opts))
        opts = varargin;
    else
        set(self.h.text_ns,'String',num2str(td(1)));
        set(self.h.text_nv,'String',num2str(td(2)));
        
    end
    
    if ismember('view',opts)
        buttonvals = zeros(1,3);
        buttonvals(self.orient) = 1;
        set(self.h.button_row,'Value',buttonvals(1));
        set(self.h.button_col,'Value',buttonvals(2));
        set(self.h.button_slc,'Value',buttonvals(3));
        viewUDchk = true;
    end
    
    if ismember('slc',opts)
        enslc = 'Off';
        if td(1)>1
            enslc = 'On';
        end
        set(self.h.edit_slc,'String',num2str(cslc),...
                            'Enable',enslc);
        set(self.h.slider_slice,'Min',1,...
                                'Max',max(td(1),2),...
                                'Value',cslc,'Enable',enslc,...
                                'SliderStep',[1 1]/max(td(1)-1,1));
    end
    
    if ismember('4D',opts)
        envec = 'Off';
        if td(2)>1
            envec = 'On';
        end
        set(self.h.edit_vec,'String',num2str(self.vec),...
                            'Enable',envec);
        set(self.h.slider_4D,'Min',1,...
                             'Max',max(td(2),2),...
                             'Value',self.vec,'Enable',envec,...
                             'SliderStep',[1 1]/max(td(2)-1,1));
        set(self.h.edit_veclabel,'String',self.img.labels{self.vec},...
                                 'Enable','On');
    end
    
    if any(ismember({'4D','clim'},opts))
        [vext,clim,cthr] = self.getProp('ValLim','cLim','thresh');
        cpad = diff(vext) / 2;
        set(self.h.slider_cmin,'Min',(vext(1)-cpad),'Max',(vext(2)+cpad),...
                                'Value',max(clim(1),vext(1)-cpad),'Enable','On');
        set(self.h.slider_cmax,'Min',(vext(1)-cpad),'Max',(vext(2)+cpad),...
                                'Value',min(clim(2),vext(2)+cpad),'Enable','On');
        set(self.h.edit_cmin,'String',num2str(clim(1)),'Enable','On');
        set(self.h.edit_cmax,'String',num2str(clim(2)),'Enable','On');
    
        infi = isinf(cthr);
        cthr(infi) = vext(infi);
        estr = {'on','on'};
        estr(infi) = {'off'};
        set(self.h.checkbox_thMin,'Value',~infi(1));
        set(self.h.slider_thMin,'Enable',estr{1},'Min',vext(1),'Max',min(vext(2),cthr(2)),...
            'Value',cthr(1));
        set(self.h.edit_thMin,'Enable',estr{1},'String',num2str(cthr(1)));
        set(self.h.checkbox_thMax,'Value',~infi(2));
        set(self.h.slider_thMax,'Enable',estr{2},'Min',max(vext(1),cthr(1)),'Max',vext(2),...
            'Value',cthr(2));
        set(self.h.edit_thMax,'Enable',estr{2},'String',num2str(cthr(2)));
    end
    
    if viewUDchk
        self.dispUDview;
    else
        self.dispUDslice;
    end
end