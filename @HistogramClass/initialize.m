% HistogramClass function
% Re-initialize and set limits/bins
function initialize(self,xmin,xmax,voxvol,nbins)
if (nargin > 2)
    if (xmin < xmax) % Only proceed if limits are valid
        if (nargin > 3)
            self.voxvol = voxvol;
        end
        if (nargin == 5)
            if (nbins > 1)
                self.nbins = nbins;
            end
        end
        self.binLocs = (xmin:((xmax-xmin)/(self.nbins-1)):xmax)';
        % Set plot x-axis limits
        set(self.haPlot,'XLim',[xmin xmax]);
    end
end