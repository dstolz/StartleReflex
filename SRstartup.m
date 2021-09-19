% set paths for Startle Reflex directory

fprintf('** Setting Startle Reflex Paths **')
p = genpath([matlabroot,'\work\StartleReflex']);
if isempty(p)
    p = genpath('C:\Matlab_Work\StartleReflex');
end

m = false(size(p));

s = strfind(p,';');

% ignore SVN directories
k = 1;
for i = 1:length(s)
    if strfind(p(k:s(i)),'.svn')
        m(k:s(i)) = true;
    end
    k = s(i)+1;
end

p(m) = [];

addpath(p);
clear
clc