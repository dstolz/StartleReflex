function h = SRPlotResult(varargin)
% SRPlotResult(data,cfg)
% SRPlotResult(ax,data,cfg)
% h = SRPlotResult(...)
%
% 
% DJS (c) 2011


if nargin < 3
    error('SRPlotResult requires atleast 3 inputs');
elseif nargin == 3
    ax = gca;
else
    ax = varargin{1};
end

data = varargin{end-1};
cfg  = varargin{end};

if ~isfield(cfg,'uv'),          error('cfg.uv is a required field');            end
if ~isfield(cfg,'measure'),     error('cfg.measure is a required field');       end
if ~isfield(cfg,'plotmeasure'), error('cfg.plotmeasure is a required field');   end

uv = cfg.uv;

midx = strcmpi(cfg.plotmeasure,cfg.measure);

m = squeeze(mean(data(:,midx,:)));
% s = squeeze(std(data(:,midx,:)));

% h = errorbar(ax,uv(:,1),m,m-s,m+s);
h = plot(ax,uv(:,1),m);
set(h,'linewidth',2,'linestyle','-','marker','o');

if any(uv)
    xlim(ax,[min(uv(:,1))-0.1*abs(min(uv(:,1))) 1.1*abs(max(uv(:,1)))]);
end







