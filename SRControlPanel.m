function varargout = SRControlPanel(varargin)
% Main Control GUI for Startle Reflex Software

% DJS (c) 2011

% Last Modified by GUIDE v2.5 31-Jul-2011 18:13:38

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @SRControlPanel_OpeningFcn, ...
                   'gui_OutputFcn',  @SRControlPanel_OutputFcn, ...
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


% --- Executes just before SRControlPanel is made visible.
function SRControlPanel_OpeningFcn(hObject, eventdata, handles, varargin) %#ok<INUSL>
% Choose default command line output for SRControlPanel
handles.output = hObject;

handles.SETTINGS.expt_file = [];
handles.SETTINGS.sched_file = [];
handles.SETTINGS.boxes = [];

handles.regKey = 'HKCU\Software\MATHWORKS\MATLAB\StartleReflex';
% handles.settingsfn = GetRegKey(handles.regKey,'settingsfn');
handles.settingsfn = getpref('StartleReflex','settingsfn',[]);

if ~isempty(handles.settingsfn)
    tbLoadSettings(handles,handles.settingsfn)
end

guidata(hObject, handles);


% --- Outputs from this function are returned to the command line.
function varargout = SRControlPanel_OutputFcn(hObject, eventdata, handles)  %#ok<INUSL>
varargout{1} = handles.output;




function figure1_CloseRequestFcn(hObject, eventdata, handles) %#ok<INUSL,DEFNU>

state_halt_Callback(handles.state_halt, [], handles) 

% SetRegKey(handles.regKey,'settingsfn',handles.settingsfn);
setpref('StartleReflex','settingsfn',handles.settingsfn);

% Hint: delete(hObject) closes the figure
delete(hObject);













%% Experiment Setup GUI
function setup_locate_expt_Callback(hObj, ~, h) %#ok<INUSL,DEFNU>
[fn,pn] = uigetfile('*.sres','Locate Experiment Setup File (*.sres)');

if ~fn, return; end

[~,n,~] = fileparts(fn);
set(h.setup_experiment_file,'String',n);

h.SETTINGS.expt_file = fullfile(pn,fn);

guidata(gcbo,h);

CheckReady(h);

function setup_locate_sch_Callback(hObj, ~, h) %#ok<INUSL,DEFNU>
[fn,pn] = uigetfile('*.srsf','Locate Schedule File (*.srsf)');

if ~fn, return; end

[~,n,~] = fileparts(fn);
set(h.setup_schedule_file,'String',n);

h.SETTINGS.sched_file = fullfile(pn,fn);

guidata(gcbo,h);

CheckReady(h);

function setup_boxes_CellEditCallback(hObj, evnt, h) %#ok<INUSL,DEFNU>
d = get(hObj,'Data');

ind = [];
for i = 1:size(d,1)
    if isempty(d{i,1}) || isnan(d{i,1}), ind(end+1) = i; end %#ok<AGROW>
end
d(ind,:) = [];

h.SETTINGS.boxes = cell2mat(d(:,1));

for i = 1:size(d,1) 
    if isempty(strtrim(d{i,2}))
        d{i,2} = num2str(d{i,1},'Box_%d');
    end
end
h.SETTINGS.alias = d(:,2);

d(end+1,:) = {[],''};
set(hObj,'Data',d);

guidata(gcbo,h);

CheckReady(h);

function CheckReady(h)
set(findobj(h.figure1,'-regexp','tag','state*'),'Enable','off');
if ~isempty(h.SETTINGS.sched_file) && ~isempty(h.SETTINGS.expt_file) ...
        && ~isempty(h.SETTINGS.boxes)
    set(h.state_connect,'Enable','on');
end

























%% Program State Control
function state_connect_Callback(hObj, ~, h) %#ok<DEFNU>
global G_RP G_PA5 G_zBUS G_STATE

set(gcf,'pointer','watch'); drawnow

set(hObj,'Enable','off');
set(hObj,'String','Connecting...');
drawnow

load(h.SETTINGS.expt_file, '-mat');
load(h.SETTINGS.sched_file,'-mat');

boxes = h.SETTINGS.boxes;

h.experiment = CheckExperiment(experiment);
h.schedule   = CheckSchedule(schedule,boxes);

% copy module functions to handles structure
h.STIMMODS = h.experiment.STIMMODS;
h.ACQMODS  = h.experiment.ACQMODS;

[G_RP,G_PA5,G_zBUS] = ConnectHardware(experiment,schedule);

w = whos('G_RP');
if isempty(w) || ~strcmp(w.class,'COM.RPco_x')
    set(hObj,'String','Connect/Load');
    set(hObj,'Enable','on');
    set(gcf,'pointer','arrow');
    return
end

s = findobj(h.figure1,'-regexp','Tag','setup*','-and','-not','Type','uipanel');
set(s,'Enable','off');

set(hObj,'String','Connected');
set(hObj,'Enable','off');
set(h.state_run,'Enable','on');
set(h.state_halt,'Enable','on');

h = CreateSRPlots(h.SETTINGS.boxes,h);

figure(h.figure1);

h.schidx = [];
h.nsidx  = [];

guidata(hObj,h);

G_STATE = 1;

set(gcf,'pointer','arrow');

function state_run_Callback(hObj, ~, h) %#ok<DEFNU>
global G_RP G_PA5 G_zBUS G_PAUSE G_STATE

G_PAUSE = false;

exp = h.experiment;

set(hObj,'Enable','off');
set(hObj,'String','Running');

% Start timer
T = CreateStartleTimer;

set(h.state_pause,'Enable','on');
set(h.state_halt, 'Enable','on');

% TO DO: **** Trial Duration (td) should be user-defined option with boundries **** %%%%
h.SETTINGS.TrialDuration = 500; % in ms
for i = 1:length(G_RP)
    h.SFreq(i) = G_RP(i).GetSFreq;
    G_RP(i).SetTagVal('TrialDuration',h.SETTINGS.TrialDuration);
end

if ~isempty(G_zBUS)
    h.nracks = GetNRacks(G_zBUS,exp.module);
else
    h.nracks = [];
end

% set parameters for next trial
[h.schidx,h.nsidx] = UpdateRPtags(G_RP,G_PA5,h,[]);

guidata(hObj,h);

h.experiment.begintime = datestr(now,'HH:MM:SS');
start(T);

G_STATE = 2;

function state_pause_Callback(hObj, ~, h) %#ok<INUSD,DEFNU>
global G_PAUSE

G_PAUSE = true; %#ok<NASGU>

T = timerfind('tag','STARTLETIMER');

h = msgbox(sprintf('Waiting for the current trial to finish...\n\nPlease wait...'), ...
    'PAUSING','warn','modal');

set(h,'Pointer','watch'); drawnow

delete(findobj(h,'type','uicontrol'));

% wait until the current trial finishes running
while strcmp(get(T,'Running'),'on')
    pause(0.1);
end

set(h,'Pointer','arrow');

close(h);

uiwait(warndlg(sprintf('EXPERIMENT PAUSED.\n\nClick OK to resume.'), ...
    'Paused','modal'));

G_PAUSE = false;

start(T);

function state_halt_Callback(hObj, skipconfirm, h) 
global G_RP G_PA5 G_STATE

if isempty(skipconfirm), skipconfirm = true; end
if isempty(G_STATE),     G_STATE = 0;        end

if ~skipconfirm || (G_STATE > 1 && G_STATE < 4)
    if strcmp(questdlg('Are you certain you want to stop the experiment?', ...
            'Stop Experiment','Stop Experiment','Cancel','Cancel'),'Cancel')
        return
    end
end

h.experiment.endtime = datestr(now,'HH:MM:SS');

set(hObj,'Enable','off');

T = timerfind('tag','STARTLETIMER');
if ~isempty(T)
    stop(T);
    delete(T);
    clear T
end

% Set maximum attenuation
w = whos('G_PA5');
if ~isempty(w) && strcmp(w.class,'COM.PA5_x')
    for i = 1:length(G_PA5)
        G_PA5(i).SetAtten(120);
        delete(G_PA5(i));
    end
end

% Halt RP modules
w = whos('G_RP');
if~isempty(w) && strcmp(w.class,'COM.RPco_x')
    for i = 1:length(G_RP)
        G_RP(i).ClearCOF;
        delete(G_RP(i));
    end
end

f = findobj('Type','figure','-and','Name','TDTFIG');
close(f);

s = findobj(h.figure1,'-regexp','Tag','setup*','-and','-not','Type','uipanel');
set(s,'Enable','on');

set(h.state_connect,'String','Connect/Load','Enable','on');
set(h.state_pause,'Enable','off');
set(h.state_run,'String','Run','Enable','off');

if G_STATE > 1
    PromptSaveData(h);
end

G_STATE = 0;

















%% TDT Functions
function [RP,PA5,zBUS] = ConnectHardware(e,s)
f = findobj('Type','figure','-and','Name','TDTFIG');
if isempty(f)
    f = figure('Name','TDTFIG','Visible','off');
end
set(0,'CurrentFigure',f);

% initialize PA5 modules
n = s.writemodule < 0;
n = abs(s.writemodule(n));
if isempty(n)
    PA5 = [];
else
    for i = 1:length(n)
        PA5(i) = actxcontrol('PA5.x',[1 1 1 1],f); %#ok<AGROW>
        PA5(i).ConnectPA5(e.ct,n(i));
        PA5(i).SetAtten(120);
        PA5(i).Display(sprintf('PA5%d READY',i),0);
    end
end

% initialize RP modules
mods = e.module;
for i = 1:length(mods)
    [RP(i),s] = TDT_SetupRP(mods(i).type,mods(i).id,e.ct,mods(i).path); %#ok<NASGU,AGROW>
end

if strcmp(e.ct,'GB')
    % connect zBus for GB interfaces only
    zBUS = actxcontrol('ZBUS.x',[1 1 1 1],f);
    zBUS.ConnectZBUS(e.ct);
else
    zBUS = [];
end

function nracks = GetNRacks(zBus,mods)
dts = {'PA5' 'RP2' 'RL2' 'RA16' 'RV8' 'RX5' 'RX6' 'RX7' 'RX8' 'RZ2' 'RZ5'};
dti = [33 35 36 37 38 45 46 47 48 50 53];

for i = 1:length(mods)
    ind = strcmp(mods(i).type,dts);
    dt(i) = floor(zBus.GetDeviceAddr(dti(ind),mods(i).id)/2); %#ok<AGROW>
end
nracks = length(unique(dt));

function [schidx,nsidx] = UpdateRPtags(G_RP,G_PA5,h,schidx)

% boxes = [h.SRBox.id];

sch = h.schedule;

trials = sch.trials;

if sch.randomize
    % select random trial
    if isempty(schidx)
        schidx = zeros(size(trials,1),1);
    end
    
    % give priority to least chosen trials
    i = min(schidx);
    i = find(schidx == i);
    r = randperm(length(i));
    x = i(r(1));
    schidx(x) = schidx(x) + 1;
    nsidx = x;
else
    % increment schidx
    if isempty(schidx), schidx = 0; end
    
    schidx = schidx + 1;
    x = mod(schidx,size(trials,1));
    if x == 0, x = size(trials,1); end
    nsidx = x;
end

for j = 1:length(sch.writemodule)
    e = 0;
    m = sch.writemodule(j);
    par = trials{nsidx,j};
    
    if length(par) == 2 % random value between boundaries (from flat distr.)
        par = fix(par(1) + (par(2) - par(1)) .* rand(1));
    end
    
    if m < 0 % update G_PA5
        m = abs(m);
        G_PA5(m).SetAtten(trials{nsidx,j});
        
    else % update G_RP
        n = sch.writeparams{j};
            
            if isscalar(par)
                % set value
                e = G_RP(m).SetTagVal(n,par);
                
            elseif ~ischar(par) && ismatrix(par)
                % write buffer
                v = trials{nsidx,j};
                e = G_RP(m).WriteTagV(n,0,reshape(v,1,numel(v)));
                
            elseif ischar(par)
                % load from file
                load(par);
                e = G_RP(m).SetTagVal(['Size' n],length(stim.(stim.tag))); %#ok<NASGU>
                v = stim.(stim.tag);
                e = G_RP(m).WriteTagV(n,0,reshape(v,1,numel(v)));
                
            end
            
            if ~e
                fprintf(2,'** WARNING: Parameter: ''%s'' was not updated\n',n);
            end
            
    end
end

function vals = ReadRPtags(RP,h)
vals = [];

% boxes = [h.SRBox.id];

sch = h.schedule;

if ~isfield(sch,'vals'), sch.vals = []; end

for i = 1:length(RP)
    for j = 1:length(sch.readmodule)
        if sch.readmodule(j) ~= i, continue; end
        n = sch.readparams{j};
        
        % DataBuffers are handled by ReadDataBuffers fcn
        if strfind(n,'DataBuffer'), continue; end
        
        %             if ~any(n == '~'), n = sprintf('%s~%d',n,boxes(b)); end
        
        %             dt = char(RP(i).GetTagType(n));
        %             switch dt
        %                 case {'I','S','L'}
        vals.(n) = RP(i).GetTagVal(n);
        %                 vals(k) = RP(i).GetTagVal(n); %#ok<AGROW>
        
        %             case 'D'
        %                 vals{k} = RP(i).ReadTagV(n,0,v); %#ok<AGROW>
        %             end
    end
end

function buffer = ReadDataBuffers(RP,h)
boxes = [h.SRBox.id];

aid = h.ACQMODS;

td = ceil(h.SETTINGS.TrialDuration / 1000 * h.SFreq(aid(1)))-1;

buffer = zeros(td,length(boxes));

for i = 1:length(aid)
    for b = 1:length(boxes)
        n = num2str(boxes(b),'DataBuffer~%d');
        buffer(:,b) = RP(aid(i)).ReadTagV(n,0,td);
    end
end

if all(all(buffer==0))
    error('No data acquired')
end























%% Timer Function
function T = CreateStartleTimer
T = timerfind('tag','STARTLETIMER');

if isempty(T), delete(T); end

T = timer('tag','STARTLETIMER', ...
    'ExecutionMode','singleShot','StartDelay',0.2, ...
    'StartFcn',{@StartleTimer_StartFcn,gcf}, ...
    'StopFcn', {@StartleTimer_StopFcn, gcf},  ...
    'TimerFcn',{@StartleTimer_TimerFcn,gcf}, ...
    'ErrorFcn',{@StartleTimer_ErrorFcn,gcf});

function StartleTimer_StartFcn(hObj,evnt,f) %#ok<INUSL>
global G_RP 

h = guidata(f);

for i = 1:length(G_RP)
    G_RP(i).SetTagVal('TrialDuration',h.SETTINGS.TrialDuration); % ms
end

function StartleTimer_TimerFcn(hObj,evnt,f)  %#ok<INUSL>
global G_RP

h = guidata(f);
s = h.schedule;

TriggerTrial(h.nracks);

% wait for trial to be over
pause(h.SETTINGS.TrialDuration/1000+0.1);

% Read and store Tags
if ~isfield(s,'vals')
    s.vals = ReadRPtags(G_RP,h);
else
    s.vals(end+1) = ReadRPtags(G_RP,h);
end

% Read Data Buffers
buffer = ReadDataBuffers(G_RP,h);

toff = s.vals(end).SRDelay;
tidx = sum(h.schidx);
for i = 1:size(buffer,2)
    h.SRBox(i).waveform(:,tidx) = buffer(:,i);
    h.SRBox(i).tvec = linspace(-toff, ...
        1000 * size(h.SRBox(i).waveform,1) / h.SFreq(h.ACQMODS(1))-toff, ...
        size(h.SRBox(i).waveform,1));    
end

h.schedule = s;

% Plot data
PlotBuffers(h);

guidata(f,h);

function StartleTimer_StopFcn(hObj,evnt,f) %#ok<INUSL>
global G_RP G_PA5 G_PAUSE G_STATE

h = guidata(f);
s = h.schedule;

% are we done yet?
if all(h.schidx == s.nreps)
    G_STATE = 4;
    state_halt_Callback(h.state_halt,true,h)
    return
end

% set parameters for next trial
[h.schidx,h.nsidx] = UpdateRPtags(G_RP,G_PA5,h,h.schidx);
guidata(f,h);

sd = min(s.ITI) + (max(s.ITI) - min(s.ITI)) * rand(1);
sd = fix(sd * 1000)/1000; % round to nearest millisecond
set(hObj,'StartDelay',sd);

if ~G_PAUSE, start(hObj); end

function StartleTimer_ErrorFcn(hObj,evnt,f) %#ok<INUSD>

function TriggerTrial(nracks)
% NRACKS is needed to determine trigger sync delay for zBus.  Not used for
% USB connection

global G_RP G_zBUS

% Trigger trial
if isempty(G_zBUS) % USB
    for i = 1:length(G_RP)
        G_RP(i).SoftTrg(1);
    end
else % GB
    G_zBUS.zBusTrigA(0,0,nracks*2+1);
end































%% Startle Reflex Plot GUI
function h = CreateSRPlots(boxes,h)
set(h.tb_LocateSRPlots,'Enable','on');

srp = findobj('Tag','SRPlots');
if isempty(srp) || ~isfield(h,'SRPlots')
    h.SRPlots = figure('Tag','SRPlots', ...
        'Name','Startle Reflex', ...
        'NumberTitle','off');
end

ncol = floor(sqrt(length(boxes)));
nrow = ceil(length(boxes) / ncol);

if isfield(h,'SRBox'), h = rmfield(h,'SRBox'); end
for i = 1:length(boxes)
    h.SRBox(i).ax = subplot(nrow,ncol,i, ...
        'Parent',h.SRPlots, ...
        'tag',num2str(boxes(i),'SRBox %d'));
    set(h.SRBox(i).ax,'xgrid','on','ygrid','on','box','on');
%     x = min(xlim(h.SRBox(i).ax));
%     y = max(ylim(h.SRBox(i).ax));
%     text(x,y,h.SRBox(i).ax, ...
%         'Parent',h.SRBox(i).ax,'FontSize',10, ...
%         'VerticalAlignment','Bottom', ...
%         'HorizontalAlignment','Left');
    h.SRBox(i).waveform = [];
    h.SRBox(i).tvec     = [];
    h.SRBox(i).id       = boxes(i);
    h.SRBox(i).alias    = h.SETTINGS.alias{i};
end

set(h.SRPlots,'CloseRequestFcn',@CloseSRPlots);

function CloseSRPlots(hObj,evnt) %#ok<INUSD>
global G_STATE

if G_STATE > 0, return; end

f = findobj('Name','SRControlPanel','-and','Type','figure');
if ~isempty(f)
    h = guidata(f);
end

try
    delete(h.SRPlots);
catch %#ok<CTCH>
    delete(gcf);
end

function PlotBuffers(h)
mV = 0; % scale together
for i = 1:length(h.SRBox)
    m = max(abs(h.SRBox(i).waveform(:,end)));
    if m > mV, mV = m; end
end
mV = mV * 1.1;

ncol = floor(sqrt(length(h.SRBox)));
% nrow = ceil(length(h.SRBox) / ncol);

delete(findobj('tag','SRStimOnset'));

for i = 1:length(h.SRBox)
    t = h.SRBox(i).tvec;
    
    ax = h.SRBox(i).ax;
    
    cla(ax);
    
    xlim(ax,[min(t) max(t)]);
    if ~isnan(mV), ylim(ax,[-mV mV]); end
    
    hold(ax,'on');
    if size(h.SRBox(i).waveform,2) > 1
        plot(ax,t,h.SRBox(i).waveform(:,end-1), ...
            '-','LineWidth',1,'Color',[0.69 0.69 1]);
    end
    plot(ax,t,h.SRBox(i).waveform(:,end), ...
        '-','LineWidth',2,'Color',[0 0 1]);
    set(ax,'XGrid','on','YGrid','on');
    hon = plot(ax,[0 0],ylim(ax),'-k','LineWidth',1);
    set(hon,'tag','SRStimOnset');
    box(ax,'on');
    hold(ax,'off');
    
    title(ax,sprintf('%s (%d)',h.SRBox(i).alias,h.SRBox(i).id));
    
    if length(h.SRBox) == 1 || i == length(h.SRBox) - ncol + 1
        ylabel(ax,'amplitude (V)');
        xlabel(ax,'time (ms)');
    end
    
end

f = ancestor(ax,'figure');

s = h.schedule;
n = sprintf('Startle Reflex | Trial %d of %d',sum(h.schidx),size(s.trials,1) * s.nreps);
set(f,'Name',n);














%% Save Data
function r = PromptSaveData(h)
r = 0;

if isfield(h.experiment,'resultsdir') && ~isempty(h.experiment.resultsdir)
    d = h.experiment.resultsdir;
else
    d = cd;
end

d = uigetdir(d,'Pick a directory to save data');

if ~d, return; end

h.experiment.resultsdir = d;

SRBox = h.SRBox;

% check for duplicate in directory
df = dir(fullfile(d,'*.mat'));
df = {df.name};
for i = 1:length(df), df{i}(end-3:end) = []; end
for i = 1:length(SRBox)
    if ~any(strcmp(SRBox(i).alias,df)), continue; end
    
    b = questdlg(sprintf(['A file with the name ''%s.mat'' already exists in the selected directory.\n\n', ...
        'What would you like to do?'],SRBox(i).alias), ...
        'File Exists','Overwrite','Rename','Cancel','Cancel');
    
    switch b
        case 'Continue'
            continue
            
        case 'Rename'
            opt.WindowStyle = 'modal'; opt.Interpreter = 'none'; opt.Resize = 'off';
            a = inputdlg({sprintf('Rename results for ''%s'' (%d):', ...
                SRBox(i).alias,SRBox(i).id)},'Rename',1,{SRBox(i).alias},opt);
            if isempty(a)
                uiwait(msgbox('Note: Files were NOT saved'));
                return
            end
            h.SRBox(i).alias = a;
            PromtSaveData(h);
            return
            
        case 'Cancel'
            uiwait(msgbox('Note: Files were NOT saved'));
            return
    end
end

set(gcf,'pointer','watch'); drawnow
for i = 1:length(SRBox)
    fprintf('\nSaving %s (box %d) ...',SRBox(i).alias,SRBox(i).id)
    StartleData = SRBox(i);
    StartleData.fsample    = h.SFreq(h.ACQMODS(1));
    StartleData.schedule   = h.schedule;
    StartleData.experiment = h.experiment;
    StartleData.date = datestr(now,'dd-mmm-yyyy');
    fn = fullfile(d,[StartleData.alias,'.mat']);
    StartleData.originalfn = fn;
    save(fn,'StartleData');
    if exist(fn,'file')
        fprintf(' SUCCESS')
    else
        fprintf(' FAILED ***')
    end
end
set(gcf,'pointer','arrow');
fprintf('\nSaved to directory:\n''%s''\n',d);

SRResultsViewer([],d);

r = 1;




























%% GUI Functions
function tbSaveSettings(hObj,h) %#ok<INUSL,DEFNU>
if ~isfield(h,'SETTINGS'), return; end

SETTINGS = h.SETTINGS; %#ok<NASGU>

[fn,pn] = uiputfile({'*.srcs','Startle Reflex Settings'},'Save Settings');

if ~fn, return; end

save(fullfile(pn,fn),'SETTINGS','-mat');

s = sprintf('Settings saved as:\n\n%s',fullfile(pn,fn));

msgbox(s,'Save Settings','Help','modal');

function tbLoadSettings(h,fn)
if ~exist('fn','var') || isempty(fn)
    [fn,pn] = uigetfile({'*.srcs','Startle Reflex Settings'},'Load Settings');
    if ~fn, return; end
    fn = fullfile(pn,fn);
end

if ~exist(fn,'file'), return; end

load(fn,'-mat');

if ~exist('SETTINGS','var')
    msgbox('Invalid Settings File','Load Settings','warn','modal');
    return
end

h.SETTINGS = SETTINGS;

guidata(h.figure1,h);

[~,n,~] = fileparts(SETTINGS.expt_file);
set(h.setup_experiment_file,'String',n);

[~,n,~] = fileparts(SETTINGS.sched_file);
set(h.setup_schedule_file,'String',n);

d = cell(length(SETTINGS.boxes)+1,2);
for i = 1:length(SETTINGS.boxes)
    d{i,1} = SETTINGS.boxes(i);
    d{i,2} = SETTINGS.alias{i};
end
set(h.setup_boxes,'Data',d);

CheckReady(h);

h.settingsfn = fn;
guidata(h.figure1,h);

function tb_LocateSRPlots(hObj,e,h) %#ok<INUSD,DEFNU>
srp = findobj('Tag','SRPlots');
if ~isempty(srp), figure(max(srp)); end





















%% Helper Functions
function experiment = CheckExperiment(experiment)
m = experiment.module;

% assign module functions 
experiment.STIMMODS = []; experiment.ACQMODS = [];
for i = 1:length(m)
    switch m(i).fcn
        case 'Stim'
            experiment.STIMMODS(end+1) = i;
        case 'Acq'
            experiment.ACQMODS(end+1)  = i;
        case 'Stim/Acq'
            experiment.STIMMODS(end+1) = i;
            experiment.ACQMODS(end+1)  = i;
    end
    
end

function schedule = CheckSchedule(schedule,boxes)
% look for tilde ('~') flag marking box id in 'readparams'
k = 1;
for i = 1:length(schedule.readparams)
    n = schedule.readparams{i};
    tildeflag = strfind(n,'~x');
    if isempty(tildeflag)
        nrp{k} = n; %#ok<AGROW>
        k = k + 1;
    else
        for j = 1:length(boxes)
            nrp{k} = strrep(n,'~x',num2str(boxes(j),'~%d')); %#ok<AGROW>
            k = k + 1;
        end
    end
end
schedule.readparams = nrp;

% look for tilde ('~') flag marking box id in 'writeparams'
k = 1;
for i = 1:length(schedule.writeparams) 
    n = schedule.writeparams{i};
    tildeflag = strfind(n,'~x');
    if isempty(tildeflag)
        nwp{k} = n; %#ok<AGROW>
        k = k + 1;
    else
        for j = 1:length(boxes)
            nwp{k} = strrep(n,'~x',num2str(boxes(j),'~%d')); %#ok<AGROW>
            k = k + 1;
        end
    end
end
schedule.writeparams = nwp;
