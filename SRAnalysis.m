function varargout = SRAnalysis(data,cfg)
%   result = SRAnalysis(data,cfg);
%   [result,measure] = SRAnalysis(data,cfg);
%   [result,measure,vals] = SRAnalysis(data,cfg);
% 
%   Input:
%       data ... Matlab (*.mat) file result from Startle Reflex experiment
%                using SRControlPanel
% 
%       cfg structure which must contain fields:
%           .dvar      ... Dependant variable (ex: 'PPdB'; ex: {'PPdB','SRdB'});
%       optional cfg fields:
%           .rms_win   ... RMS measurement window (in milliseconds).  Default = [0 50]
%           .rms_blwin ... Baseline RMS measurement window (in milliseconds).  Default = [-50 0]
%
%   Output:
%       result  ... Results from analysis as an NxMxP matrix wwhere:
%                   N = replicates; M = measure; P = variable;
%       measure ... labels of measure corresponding to column (M) dimension
%                   of result output.
%       vals    ... Value pairs of cfg.dvar parameters.  Rows correspond to
%                   third dimension (P) in result output.
%
% DJS (c) 2011


if ~exist('cfg','var'), cfg = []; end
if ~isfield(cfg,'rms_win'),   cfg.rms_win   = [0 50];  end
if ~isfield(cfg,'rms_blwin'), cfg.rms_blwin = [-50 0]; end

if ~isfield(cfg,'dvar') || isempty(cfg.dvar)
    error('CFG field ''dvar'' is required');
end
if ~iscell(cfg.dvar), cfg.dvar = cellstr(cfg.dvar); end

rp = data.schedule.readparams;
rv = data.schedule.vals;

if ~all(ismember(cfg.dvar,rp)), error('A specified cfg.dvar was not found in readparams'); end

t = sigfeatures(data.waveform,data.tvec,cfg);
m = cell2mat(squeeze(struct2cell(t)));

uv = unique([rv.(cfg.dvar{1})]);
uv = uv(:);
if numel(cfg.dvar) == 2
    [a,b]   = meshgrid(uv,unique([rv.(cfg.dvar{2})]));
    uv      = reshape(a,numel(a),1);
    uv(:,2) = reshape(b,numel(b),1);
end

for i = 1:size(uv,1)
    ind = true(1,length(rv));
    for j = 1:size(uv,2)
        ind = ind & [rv.(cfg.dvar{j})] == uv(i,j);
    end
    c(:,:,i) = m(:,ind)';  %#ok<AGROW>
    idx(:,i) = find(ind); %#ok<AGROW>
end

varargout{1} = c;
varargout{2} = fieldnames(t)';
varargout{3} = uv;
varargout{4} = idx;


function trials = sigfeatures(wave,tvec,cfg)
blind = tvec >  cfg.rms_blwin(1) & tvec <= cfg.rms_blwin(2);
tind  = tvec >= cfg.rms_win(1)   & tvec <  cfg.rms_win(2);

trials.rms_bl = std(wave(blind,:)); % baseline RMS
trials.rms    = std(wave(tind,:));  % startle RMS

[v,x] = max(wave(tind,:));
trials.pospeakval = v;
trials.pospeaklat = tvec(x+find(tind,1)-1);

[v,x] = min(wave(tind,:));
trials.negpeakval = v;
trials.negpeaklat = tvec(x+find(tind,1)-1);

trials.pos2negamp = trials.pospeakval     - trials.negpeakval;
trials.pos2neglat = abs(trials.pospeaklat - trials.negpeaklat);

