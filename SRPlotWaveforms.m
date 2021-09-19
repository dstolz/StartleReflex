function h = SRPlotWaveforms(varargin)
% SRPlotWaveforms(startledata,cfg)
% SRPlotWaveforms(ax,startledata,cfg)
% h = SRPlotWaveforms(...)
% 
% DJS (c) 2011

if nargin < 3
    error('SRPlotWaveforms requires atleast 3 inputs');
elseif nargin == 3
    ax = gca;
else
    ax = varargin{1};
end

data = varargin{end-1};
cfg  = varargin{end};

idx = cfg.idx;

h = plot(ax,data.tvec,data.waveform(:,idx));
hold(ax,'on');
set(h,'color',[0.6 0.6 0.6]);
h(end+1) = plot(ax,data.tvec,mean(data.waveform(:,idx),2),'k','linewidth',2);
hold(ax,'off');

xlim(ax,[data.tvec(1) data.tvec(end)]);

mv = max(max(abs(data.waveform(:,idx))));
ylim(ax,[-mv mv]);










