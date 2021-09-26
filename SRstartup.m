function p = SRstartup
%[p] = SRstartup
% 
% set paths for Startle Reflex directory
%
% updated 9/2021 DJS

fprintf('Setting Startle Reflex Paths ...')

p = which(mfilename);

p = genpath(fileparts(p));

% p = strsplit(p,';');
% ind = contains(p,'.git') | cellfun(@isempty,p);

p = strsplit(p,';');
ind = cellfun(@isempty,p);

p(ind) = [];

p = strjoin(p,';');
addpath(p);


fprintf(' done\n')


if nargout == 0, clear p; end

