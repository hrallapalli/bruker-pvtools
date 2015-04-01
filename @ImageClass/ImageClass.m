classdef ImageClass < Mat3Dclass
    properties (SetObservable, SetAccess=private, GetAccess=public)
        % Inherited properties:
        %   mat         % Grayscale image (4D), inherited from Mat3Dclass
        %   dims        % Dimensions of img [rows cols slices n4D]
        %   voxsz       % Voxel size [dx dy dz]
        %   check       % Check that matrix is available
        
        % Image properties
        info                    % All image info
        fnames                  % File names of data {1 x n4D}
        valExt                  % Min/Max of each image [n4D x 2]
        mask                    % Mask to fit current image
        prm                     % PRM image class
        prmBaseVec = 1;         % Baseline image for PRM calculation
        labels = {};            % Labels for 4D (cell array)
        scaleM                  % Image scaling slope
        scaleB                  % Image scaling offset
        thresh                  % Image value thresholds [min max;...]
        
        % Image analysis options
        voxfit = false; % Check for whole-VOI fit (0) or voxel-wise fit(1)
        model           % Fitting object: FitClass or DCEclass or DiffClass
        
        % I/O options
        name                    % Name of image set
        dir                     % Current image's directory
        h                       % Structure containing ImageClass-relevant handles
    end
    methods
        % ImageClass constructor
        function self = ImageClass(hObj)
            if nargin && ~isempty(hObj) && isa(hObj,'CMIclass')
                addlistener(hObj,'ChangeView',@self.viewListen);
            end
            self.mask = MaskClass(self);
            self.prm = PRMclass(self);
            self.model = FitClass;
        end
        % ImageClass destructor
        function delete(self)
            if isstruct(self.h)
                C = struct2array(self.h);
                for i = 1:length(C)
                    if ishandle(C(i))
                        delete(C(i))
                    end
                end
            end
            if ~isempty(self.mask)
                self.mask.delete;
            end
            if ~isempty(self.prm)
                self.prm.delete;
            end
            if ~isempty(self.model)
                self.model.delete;
            end
        end
    end
end

