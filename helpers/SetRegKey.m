function varargout = SetRegKey(regKey,subKey,val)
% SetRegKey(regKey,subKey,val)
% status = SetRegKey(regKey,subKey,val)
% [status,result] = SetRegKey(regKey,subKey,val)
%
% Set value (val) for a the subKey of some registry key (regKey).
% 
% status returns false if succesful, true if error.
% 
% result returns the textual result of 'system' call.
% 
% DJS (c) 2010

error(nargchk(3,3,nargin,'struct'));
error(nargoutchk(0,2,nargout,'struct'));

if isnumeric(val),  val = num2str(val); end

str = sprintf('reg add %s /v %s /t REG_SZ /d "%s" /f', ...
    regKey,subKey,val);
[a,b] = system(str); %#ok<NASGU,NASGU>

varargout{1} = a;
varargout{2} = b;





