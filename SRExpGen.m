function varargout = SRExpGen(varargin)
% Last Modified by GUIDE v2.5 27-Feb-2011 14:50:11

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @SRExpGen_OpeningFcn, ...
                   'gui_OutputFcn',  @SRExpGen_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before SRExpGen is made visible.
function SRExpGen_OpeningFcn(hObject, eventdata, handles, varargin) %#ok<INUSL>
handles.output = hObject;

handles.INFO_CHANGED = false;

ClearGUI(handles);

% Update handles structure
guidata(hObject, handles);


% --- Outputs from this function are returned to the command line.
function varargout = SRExpGen_OutputFcn(hObject, eventdata, handles)  %#ok<INUSL>
varargout{1} = handles.output;



































%% TDT SETUP GUI
function tdt_openex_Callback(hObj, h) %#ok<DEFNU>
if get(hObj,'Value')
    set(h.tdt_rpvds,'Enable','off')
else
    set(h.tdt_rpvds,'Enable','on')
end

function tdt_rpvds_CellEditCallback(hObj, e, h) %#ok<DEFNU>
C = e.Indices;
D = e.NewData;

td = get(hObj,'Data');

switch D
    case 'PA5'
        td{C(1),4} = '< N/A >';
    
    case '< LOCATE >'
        [fn,pn] = uigetfile({'*.rco;*.rcx','RPvds Files (*.rco, *.rcx)'}, ...
            'Locate RPvds File');
        if fn
            td{C(1),4} = fullfile(pn,fn);
        end
end

set(hObj,'Data',td);
UpdateRPvdsCF(h)

function UpdateRPvdsCF(h)
td = TrimTrialDefs(get(h.tdt_rpvds,'Data'));
td = cellstr(unique(td(:,4)));
n = td(~ismember(td,{'< LOCATE >','< NONE >',''}))';
n{end+1} = '< LOCATE >'; n{end+1} = '< NONE >';

m = {'Stim' 'Acq' 'Stim/Acq'};

cf = {{'RP2','RX5','RX6','RX7','RX8','RZ5','RZ6','RM1','RM2','PA5'}, ...
    cellstr(num2str((1:10)'))', m, n};

set(h.tdt_rpvds,'ColumnFormat',cf,'rowname','numbered');



%% TOOLBAR CALLBACKS
function NewExpt(hObj,h) %#ok<DEFNU,INUSL>
if h.INFO_CHANGED, if ~PromptSave(h), return; end; end

ClearGUI(h);

function OpenExpt(hObj,h) %#ok<DEFNU,INUSL>
if h.INFO_CHANGED, if ~PromptSave(h), return; end; end

[fn,pn] = uigetfile({'*.sres','Startle Reflex Experiment File (*.sres)'}, ...
    'Select Startle Reflex Experiment File');

if ~fn, return; end

ClearGUI(h);

load(fullfile(pn,fn),'-mat');
e = experiment;

set(h.expt_name,'String',e.name);
set(h.expt_description,'String',e.description);

if ~ValidateFcnName(e.plotfunc), e.plotfunc = '<default>'; end
set(h.customfcn_plot,'String',e.plotfunc);

if ~ValidateFcnName(e.savefunc), e.savefunc = '<default>'; end
set(h.customfcn_save,'String',e.savefunc);

set(h.tdt_ct,'Value',find(strcmp(e.ct,{'GB' 'USB'})));

set(h.tdt_openex,'Value',e.useOpenEx);

set(h.tdt_rpvds,'Data',[e.RPvdsSetupData; {'','','',''}]);

function SaveExpt(hObj,h) %#ok<INUSL>
r = EnsureCompliance(h);
if ~r, return; end

[fn,pn] = uiputfile({'*.sres','Startle Reflex Experiment File (*.sres)'}, ...
    'Save Startle Reflex Experiment File');

if ~fn
    uiwait(msgbox('Warning: Experiment NOT saved','Warning','warn','modal'));
    return
end

e = DefaultExpStruct; 

e.name = get(h.expt_name,'String');
e.description = get(h.expt_description,'String');
e.plotfunc = get(h.customfcn_plot,'String');
e.savefunc = get(h.customfcn_save,'String');
e.useOpenEx   = get(h.tdt_openex,'Value');
t = cellstr(get(h.tdt_ct,'String'));
e.ct = t{get(h.tdt_ct,'Value')};

td = TrimTrialDefs(get(h.tdt_rpvds,'Data'));
e.RPvdsSetupData = td;
for i = 1:size(td,1)
    e.module(i).type = td{i,1}; 
    e.module(i).id   = str2num(td{i,2}); %#ok<ST2NM>
    e.module(i).fcn  = td{i,3};
    e.module(i).path = td{i,4}; 
end

experiment = e; %#ok<NASGU>

save(fullfile(pn,fn),'experiment','-mat');

if exist(fullfile(pn,fn),'file')
    uiwait(msgbox(sprintf('Experiment Setup Saved Successfully!\n\n%s',fullfile(pn,fn)), ...
        'Experiment Setup Saved','help','modal'));
else
    errordlg('Unable to save experiment setup file!','File Not Saved');
end


%% Helper Functions
function c = PromptSave(h)
c = 0;
b = questdlg('Some fields have been altered.  Would you like to save the current experiment?', ...
    'Save Data','Save','Continue','Cancel','Cancel');
switch b
    case 'Save'
        SaveExpt(h.tb_save_expt,h);
    case 'Cancel'
        c = true;
        return
end

function valid = ValidateFcnName(fcn)
if isempty(fcn) || strcmpi(fcn,'<default>'), valid = true; return; end

valid = exist(fcn); %#ok<EXIST>

if ~valid
    uiwait(msgbox(sprintf('The function ''%s'' was not found on the Matlab path',fcn), ...
        'Custom Function','warn','modal'));
end

function r = EnsureCompliance(h)
r = 1;

function ClearGUI(h)
set(h.expt_name,'String','');
set(h.expt_description,'String','');
set(h.customfcn_plot,'String','<default>');
set(h.customfcn_save,'String','<default>');
set(h.tdt_openex,'Value',0);
set(h.tdt_rpvds,'Data',[{'RP2','1','Stim','< NONE >'}; repmat({''},3,4)]);
UpdateRPvdsCF(h);



function s = DefaultExpStruct
s.name = '';
s.description = '';
s.useOpenEx = false;
s.resultsdir = '';
s.ct = 'GB';
s.plotfunc = [];
s.savefunc = [];
s.module   = [];

function td = TrimTrialDefs(td)
ind = [];
for i = 1:size(td,1)
    if isempty(td{i,1})
        ind(end+1) = i;  %#ok<AGROW>
    end
end
td(ind,:) = [];
