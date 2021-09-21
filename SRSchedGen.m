function varargout = SRSchedGen(varargin)

% Last Modified by GUIDE v2.5 11-Mar-2011 21:42:25

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @SRSchedGen_OpeningFcn, ...
                   'gui_OutputFcn',  @SRSchedGen_OutputFcn, ...
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

% --- Executes just before SRSchedGen is made visible.
function SRSchedGen_OpeningFcn(hObject, eventdata, handles, varargin) %#ok<INUSL>
handles.output = hObject;

set(handles.table_basicdefs,'data',DefaultBasicDefs);
set(handles.table_basicdefs,'ColumnEditable',logical([0 1 1 1 1 1]));
set(handles.table_trialdefs,'data',DefaultRowDef);

sch = TD2BHVR([],get(handles.table_basicdefs,'Data'));
PlotSRSchema(sch,handles);


% Update handles structure
guidata(hObject, handles);

% --- Outputs from this function are returned to the command line.
function varargout = SRSchedGen_OutputFcn(hObject, eventdata, handles)  %#ok<INUSL>
varargout{1} = handles.output;

















% ------------------------------------
function sch = TD2BHVR(sch,td)
sch.writemodule = [];
sch.writeparams = [];
sch.readmodule  = [];
sch.readparams  = [];
bhvr = [];
for i = 1:size(td,1)
    m = td{i,2};
    
    if isempty(strfind(td{i,3},'Write'))
        sch.readmodule(end+1) = m;
        sch.readparams{end+1} = td{i,1};
        continue
    end
    
    if strfind(td{i,3},'Write')
        sch.writemodule(end+1) = m;
        sch.writeparams{end+1} = td{i,1};
    end
    
    if strfind(td{i,3},'Read')
        sch.readmodule(end+1) = m;
        sch.readparams{end+1} = td{i,1};
    end
        
    if any(td{i,5}=='\') % filenames are valid
        v = td{i,5};
    else
        v = str2num(td{i,5}); %#ok<ST2NM>
    end
    
    if td{i,end} % randomized
        bhvr{end+1}{1} = 'randomized'; %#ok<AGROW>
        bhvr{end}{2} = []; %#ok<AGROW>
        bhvr{end}{3} = v; %#ok<AGROW>
    else
        if strcmp(td{i,4},'< NONE >')
            bhvr{end+1} = v; %#ok<AGROW>
        else
            bhvr{end+1}{1} = 'buddy'; %#ok<AGROW>
            bhvr{end}{2} = td{i,4}; %#ok<AGROW>
            bhvr{end}{3} = v; %#ok<AGROW>
        end
    end
end

sch = BHVR_AddTrial(sch,bhvr);

function td = TrimTrialDefs(td)
ind = [];
for i = 1:size(td,1)
    if isempty(td{i,1})
        ind(end+1) = i;  %#ok<AGROW>
    end
end
td(ind,:) = [];

function CustomFcn %#ok<DEFNU>
h = guidata(gcbo);

opts.Resize = 'on';
opts.WindowStyle = 'modal';
opts.Interpreter = 'none';


if ~isfield(h,'customfcn'), h.customfcn = ''; end

r = inputdlg('Enter name of custom function or erase to not use one.','SR', ...
    1,{h.customfcn},opts);

r = char(r);

if ~isempty(r)
    w = which(r);
    if isempty(w)
        uiwait(msgbox(sprintf('Function not found on path: "%s"',r), ...
            'custom function','error','modal'));
        r = h.customfcn;
    else
        fprintf('Custom Function = "%s" : %s\n',r,w)
    end
end

h.customfcn = r;

guidata(gcbo, h);


function SaveSchedule %#ok<DEFNU>
h = guidata(gcbo);

schedule.nreps = str2num(get(h.opt_num_blocks,'String')); %#ok<ST2NM>
schedule.randomize = get(h.opt_randomize,'Value');
schedule.ITI   = str2num(get(h.opt_iti,'String')); %#ok<ST2NM>
schedule.description = get(h.schedule_description,'String');

if ~isfield(h,'customfcn'), h.customfcn = ''; end
schedule.customfcn = h.customfcn;
    

td = get(h.table_basicdefs,'Data');
d  = TrimTrialDefs(get(h.table_trialdefs,'data'));
schedule.trialdefs{1} = td;
schedule.trialdefs{2} = d;
if ~isempty(d), td = [td; d]; end
schedule = TD2BHVR(schedule,td); 

[fn,pn] = uiputfile({'*.srsf','Save Startle Reflex Schedule File (*.srsf)'},'Save Schedule...');

if ~fn, return; end

schedule.schedule = fn;

save(fullfile(pn,fn),'schedule');

fprintf('Schedule Saved: %s\n',fullfile(pn,fn))

function LoadSchedule %#ok<DEFNU>

[fn,pn,~] = uigetfile('*.srsf','Load Startle Reflex Schedule File (*.srsf)');
if ~fn, return; end
fn = fullfile(pn,fn);

load(fn,'-mat');

if ~exist('schedule','var') || ~isstruct(schedule) || ~isfield(schedule,'trialdefs') %#ok<NODEF>
    warndlg('Schedule was found to be invalid.','Invalid Schedule','modal');
    return
end

h = guidata(gcbo);
cf = get(h.table_trialdefs,'ColumnFormat');
ub = unique(schedule.trialdefs{2}(:,4));
ub(ismember(ub,{'< NONE >','< ADD >'})) = [];
ub{end+1} = '< NONE >'; ub{end+1} = '< ADD >';
cf{4} = ub;
set(h.table_trialdefs,'ColumnFormat',cf);
set(h.table_basicdefs,'data',schedule.trialdefs{1});
if isempty(schedule.trialdefs{2}), schedule.trialdefs{2} = DefaultRowDef; end
set(h.table_trialdefs,'data',schedule.trialdefs{2});
set(h.opt_num_blocks,'String',schedule.nreps);
set(h.opt_randomize,'Value',schedule.randomize);
set(h.opt_iti,'String',num2str(schedule.ITI));
if ~isfield(schedule,'description'), schedule.description = ''; end
set(h.schedule_description,'String',schedule.description);
set(h.view_trials,'Enable','on');

td = schedule.trialdefs{1};
d  = TrimTrialDefs(schedule.trialdefs{2});
if ~isempty(d)
    td = [td; d];
end

if isfield(schedule,'customfcn'), h.customfcn = schedule.customfcn; end

guidata(gcbo,h);


% for i = 1:size(td,1)
%     if isempty(td{i,5})
%         return
%     end
% end
sch = TD2BHVR([],td);
PlotSRSchema(sch,h);


































% ---------------- GUI Callbacks --------------------
function view_trials_Callback(hObject, eventdata, handles) %#ok<INUSL,DEFNU>
f = findobj('Name','Trials');
if isempty(f)
    f = figure('Name','Trials','Units','normalized', ...
        'MenuBar','none','NumberTitle','off','DockControls','on');
    t = uitable(f,'Units','normalized','Position',[0.02 0.02 0.96 0.96]);
else
    t = findobj(f,'type','uitable');
end
dd = get(handles.table_basicdefs,'Data');
td = TrimTrialDefs(get(handles.table_trialdefs,'Data'));
sch.trialdefs = {dd; td};
if ~isempty(td)
    dd = [dd; td];
end
sch = TD2BHVR(sch,dd); 

for i = 1:numel(sch.trials)
    if isnumeric(sch.trials{i}) && length(sch.trials{i}) > 1
        sch.trials{i} = num2str(sch.trials{i});
    end
end

set(t,'data',sch.trials);
set(t,'ColumnName',sch.writeparams);
if ~isempty(t)
    set(handles.view_trials,'Enable','on');
end


































% -------------------- Table Callbacks --------------------
function table_basicdefs_CellSelectionCallback(hObject, e, handles) %#ok<DEFNU>
handles.CURRENTCELL = e.Indices;

guidata(hObject,handles);

td = get(hObject,'Data');
for i = 1:size(td,1), if isempty(td{i,5}), return; end; end
sch = TD2BHVR([],td);
PlotSRSchema(sch,handles);

function table_basicdefs_CellEditCallback(hObject, e, handles) %#ok<DEFNU>
C = e.Indices;
D = e.NewData;

td = get(hObject,'data');
cf = get(hObject,'ColumnFormat');

if C(2) == 4 % buddy
    if strcmp(D,'< ADD NEW >')
        opt.Resize = 'off';
        opt.WindowStyle = 'modal';
        opt.Interpreter = 'none';
        a = char(inputdlg('Enter Name for New Buddied Parameters:','Buddy',1,{''},opt));
        if isempty(a)
            td{C(1),C(2)} = '< NONE >';
        else
            a = strtrim(a);
            td{C(1),C(2)} = a;
            tcf = cf{4};
            i = strcmpi(a,tcf);
            if any(i) % if buddy already exists then just select it
                td{C(1),C(2)} = tcf{i};
            else % otherwise create new buddy name and select it
                cf{4} = [cellstr(a) tcf];
                set(hObject,'ColumnFormat',cf);
                set(handles.table_trialdefs,'ColumnFormat',cf);
                td{C(1),C(2)} = a;
            end
        end
    end
elseif C(2) == 6 % randomized - ensure values (5) is a range
    if td{C(1),6} == true
        v = str2num(td{C(1),5}); %#ok<ST2NM>
        if length(v) ~= 2
            helpdlg(['Enter the range for randomization; i.e. 2 values. ', ...
                'For example, in order to randomize between 2 and 10 enter: 2 10'], ...
                'Randomize');
            td{C(1),6} = false;
        end
    end
end

set(hObject,'data',td);

set(handles.view_trials,'Enable','on');
set(handles.tb_save_schedule,'Enable','on');

td = TrimTrialDefs(td);

sch = TD2BHVR([],td);
PlotSRSchema(sch,handles);

function table_trialdefs_CellSelectionCallback(hObject, e, handles) %#ok<DEFNU>
handles.CURRENTCELL = e.Indices;

guidata(hObject,handles);

td = get(hObject,'data');

if ~isempty(td{end,1}) % make sure the last row is empty for new parameters
    td(end+1,:) = DefaultRowDef;
    set(hObject,'data',td);
    set(handles.view_trials,'Enable','off');
    set(handles.tb_save_schedule,'Enable','off');
end

function table_trialdefs_CellEditCallback(hObject, e, handles) %#ok<DEFNU>
C = e.Indices;
D = e.NewData;

td = get(hObject,'data');
cf = get(hObject,'ColumnFormat');

if C(2) == 4 % buddy
    if strcmp(D,'< ADD NEW >')
        opt.Resize = 'off';
        opt.WindowStyle = 'modal';
        opt.Interpreter = 'none';
        a = char(inputdlg('Enter Name for New Buddied Parameters:','Buddy',1,{''},opt));
        if isempty(a)
            td{C(1),C(2)} = '< NONE >';
        else
            a = strtrim(a);
            td{C(1),C(2)} = a;
            tcf = cf{4};
            i = strcmpi(a,tcf);
            if any(i) % if buddy already exists then just select it
                td{C(1),C(2)} = tcf{i};
            else % otherwise create new buddy name and select it
                cf{4} = [cellstr(a) tcf];
                set(hObject,'ColumnFormat',cf);
                set(handles.table_basicdefs,'ColumnFormat',cf);
                td{C(1),C(2)} = a;
            end
        end
    end
elseif C(2) == 6 % randomized - ensure values (5) is a range
    if td{C(1),6} == true
        v = str2num(td{C(1),5}); %#ok<ST2NM>
        if length(v) ~= 2
            helpdlg(['Enter the range for randomization; i.e. 2 values. ', ...
                'For example, in order to randomize between 2 and 10 enter: 2 10'], ...
                'Randomize');
            td{C(1),6} = false;
        end
    end
end

set(hObject,'data',td);

set(handles.view_trials,'Enable','on');
set(handles.tb_save_schedule,'Enable','on');




























% -------------------- Startle Schematic --------------------
function PlotSRSchema(sch,h)
% SCHEMA is a structure with the following fields
%
% .StartleDelay
% .StartleDuration
% .StartleAmp
% .PPDelay
% .PPDuration
% .PPdB
% .BGdB
%

persistent anns

try
    ax = h.SRSchema;
    
    if ~isempty(anns)
        try delete(anns); end %#ok<TRYNC>
        anns = [];
    end
    cla(ax);
    
    hold(ax,'on');
    
    schema = DefaultSRSchema;
    fn = fieldnames(schema);
    
    for i = 1:length(sch.writeparams)
        if ~any(strcmp(sch.writeparams{i},fn)), continue; end
        schema.(sch.writeparams{i}) = cell2mat(sch.trials(:,i));
    end
    ba = schema.BGdB;
    pd = schema.PPDelay;
    pu = schema.PPDuration;
    pa = schema.PPdB;
    sd = schema.SRDelay;
    su = schema.SRDuration;
    sa = schema.SRdB;
    
    n = size(sch.trials,1);
    
    f = inline('fix(x(1) + (x(2) - x(1)) .* rand(1))');
    
    cs = hsv(n);
    set(ax,'Color',[0.98 0.98 0.98]);
    
    line([0 max(max(su))+max(max(sd))*1.5],[0 0],'LineStyle',':','Color',[0.6 0.6 0.6],'LineWidth',1);
    for i = 1:n
        if length(pd(i,:)) == 2, tpd = f(pd(i,:)); else tpd = pd(i); end
        if length(pu(i,:)) == 2, tpu = f(pu(i,:)); else tpu = pu(i); end
        if length(pa(i,:)) == 2, tpa = f(pa(i,:)); else tpa = pa(i); end
        if length(ba(i,:)) == 2, tba = f(ba(i,:)); else tba = ba(i); end
        
        
        % Pre-Pulse
        x = [0   tpd tpd tpd+tpu tpd+tpu];
        y = [tba tba tpa tpa     tba    ];
        line(x,y,'Color',cs(i,:),'LineWidth',2);
        if tpa == -100 && tba > -100
            h = text(tpd,-20,'Gap');
        else
            h = text(tpd,tpa,num2str(tpa,'%g'));
        end
        set(h,'VerticalAlignment','bottom','FontName','Arial', ...
            'Color',cs(i,:),'FontSize',6);
        
        % Background
        text(0,tba,num2str(tba,'%g'), ...
            'VerticalAlignment','bottom','FontName','Arial', ...
            'Color',cs(i,:),'FontSize',6);
        
        % Startle
        x = [tpd+tpu sd(i) sd(i) sd(i)+su(i) sd(i)+su(i) sd(i)+su(i)+1000];
        y = [tba    tba sa(i) sa(i)    tba    tba];
        line(x,y,'Color',cs(i,:),'LineWidth',2);
        text(sd(i),sa(i),num2str(sa(i),'%g'), ...
            'VerticalAlignment','bottom','FontName','Arial', ...
            'Color',cs(i,:),'FontSize',6);
        
        hold(ax,'off');
    end
    
    ylim(ax,[-20 120]);
    xlim(ax,[0 su(i)+sd(i)*1.5]);
    
    
    % if size(pd,2) == 2;
    %     x = [pd(1,1) pd(1,2)];
    %     y = [100 100];
    %     [x,y] = dsxy2figxy(ax,x,y);
    %     anns(end+1) = annotation('doublearrow',x,y,  ...
    %         'HeadStyle','vback1','HeadLength', 5, ...
    %         'LineStyle',':');
    % end
    %
    % if size(pu,2) == 2;
    %     x = [pd(1,1)+pu(1,1) pd(1,1)+pu(1,2)];
    %     y = [110 110];
    %     [x,y] = dsxy2figxy(ax,x,y);
    %     anns(end+1) = annotation('doublearrow',x,y, ...
    %         'HeadStyle','vback3','HeadLength', 5, ...
    %         'LineStyle',':');
    % end
    
    set(ax,'YTickMode','auto','XTickMode','auto');
    xlabel(ax,'Time (ms)');
    ylabel(ax,'Sound Level (dB SPL)');
catch
    
end



function s = DefaultSRSchema
s.BGdB      = -100;
s.PPDelay    = 50;
s.PPDuration = 25;
s.PPdB      = 60;
s.SRDelay    = 125;
s.SRDuration = 20;
s.SRdB      = 100;

function d = DefaultBasicDefs

d = {'BGdB',      1,'Write/Read','< NONE >','-100',false; ...
     'PPDelay',   1,'Write/Read','< NONE >','50',  false; ...
     'PPDuration',1,'Write/Read','< NONE >','25',  false; ...
     'PPdB',      1,'Write/Read','< NONE >','60',  false; ...
     'PPCalibdB', 1,'Write/Read','< NONE >','93',  false; ...
     'SRDelay',   1,'Write/Read','< NONE >','125', false; ...
     'SRDuration',1,'Write/Read','< NONE >','20',  false; ...
     'SRCalibdB', 1,'Write/Read','< NONE >','93',  false; ...
     'SRdB',      1,'Write/Read','< NONE >','100', false; ...
     'DataBuffer',1,'Read', '< NONE >','',    false};

function drd = DefaultRowDef
drd = {'' 1 'Write/Read' '< NONE >' '' false};
