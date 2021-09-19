function varargout = GetRegKey(regKey,subKey)
% GetRegKey(regKey)
% GetRegKey(regKey,subKey)
% val = GetRegKey(...)
% [val,status] = GetRegKey(...)
% [val,status,result] = GetRegKey(...)
% 
% 
% If only a registry key (regKey) is provided then all values will be
% returned in a structure contaning a field for each sub-key.
% 
% If both the regKey and subKey are provided then that value will be
% returned as a character string.
% 
% Optionally return status of 'system' call... false if succesful, true if
% error.  Optionally return the textual result of 'system' call.
%
% DJS (c) 2010

error(nargchk(1,2,nargin,'struct'));
error(nargoutchk(0,3,nargout,'struct'));

varargout = cell(size(nargout));

if isempty(whos('subKey'))
    str = sprintf('reg query %s /s',regKey);
else
    str = sprintf('reg query %s /v %s',regKey,subKey);
end    

v = [];

[a,s] = system(str);
if a
    if nargout > 0, varargout{1:nargout} = ''; end
    return
end

val = textscan(s,'%s'); val = val{1};

vind = find(ismember(val,{'REG_SZ'}));

if isempty(whos('subKey')) || isempty(subKey)
    for i = 1:length(vind)
        x = vind(i)+1;
        if x > length(val)
            t = '';
        else
            t = val{x};
        end
        v.(val{vind(i)-1}) = getval(t);  
    end
else
    v = getval(val(vind+1:end));
end

if isempty(v), v = ''; end


varargout{1} = v;
varargout{2} = a;
varargout{3} = s;

function v = getval(s)
v = '';
if iscell(s)
    for i = 1:length(s)
        v = [v ' ' char(s{i})];
    end
else
    v = s;
end
v(find(v=='*')) = [];  % for antiquated keys
v = strtrim(v);