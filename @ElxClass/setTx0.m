% ElxClass function
% Set Initial Transform Options
function setTx0(self,x,fvoxsz,fdims,varargin)

if nargin==1 % no initial transform desired
    self.Tx0 = [];
    self.T0check = false;
elseif (nargin==2) && ischar(x) && strcmp(x(end-3:end),'.txt')
    % Input file name for existing TransformParameter.txt file
    
elseif (nargin>3)
    p = inputParser;
    p.CaseSensitive = false;
    addRequired(p,'TransformParameters',@isvector);
    addRequired(p,'Spacing',@(x)isvector(x)&&(length(x)==3));
    addRequired(p,'Size',@(x)isvector(x)&&(length(x)==3));
    addParameter(p,'DefaultPixelValue',0,@isnumeric);
    addParameter(p,'FixedImageLandmarks',[],@isnumeric);
    parse(p,x,fvoxsz,fdims,varargin{:});
    
    t.NumberOfParameters = length(p.Results.TransformParameters);
    t.TransformParameters = p.Results.TransformParameters;
    if ~isempty(p.Results.FixedImageLandmarks)
        t.FixedImageLandmarks = p.Results.FixedImageLandmarks;
        np = min(length(t.TransformParameters),length(t.FixedImageLandmarks));
        if np==0
            error('Not enough landmarks selected.')
        end
        t.TransformParameters = t.TransformParameters(1:np);
        t.FixedImageLandmarks = t.FixedImageLandmarks(1:np);
        t.Transform = 'SplineKernelTransform';
        % SplineKernel Options:
        %       ThinPlateSpline
        %       ElasticBodySpline
        %       VolumeSpline
        t.SplineKernelType = 'ThinPlateSpline';
        t.SplinePoissonRatio = 0;
        t.SplineRelaxationFactor = 0;
    else
        switch t.NumberOfParameters
            case 3
                t.Transform = 'TranslationTransform';
            case 6
                t.Transform = 'EulerTransform';
            case 7
                t.Transform = 'SimilarityTransform';
            case 12
                t.Transform = 'AffineTransform';
            otherwise
                error('Invalid Transform Parameters')
        end
    end
    t.InitialTransformParametersFileName = 'NoInitialTransform';
    t.HowToCombineTransforms = 'compose';
    t.FixedImageDimension = 3;
    t.MovingImageDimension = 3;
    t.Size = p.Results.Size;
    t.Index = zeros(1,3);
    t.Spacing = p.Results.Spacing;
    % Center of the image is at (0,0,0) coordinates
    t.Origin = t.Spacing.*(1-t.Size)/2;
    t.CenterOfRotationPoint = zeros(1,3);
    t.Direction = [1 0 0 0 1 0 0 0 1];
    t.UseDirectionCosines = 'false';
    t.ResampleInterpolator = 'FinalBSplineInterpolator';
    t.FinalBSplineInterpolationOrder = 3;
    t.Resampler = 'DefaultResampler';
    t.DefaultPixelValue = p.Results.DefaultPixelValue;
    t.ResultImageFormat = 'mhd';
    t.ResultImagePixelType = 'float';
    t.FixedInternalImagePixelType = 'float';
    t.MovingInternalImagePixelType = 'float';
    t.CompressResultImage = 'false';
    
    self.Tx0 = t;
end