function varargout = SRResultsViewer(varargin)
% SRResultsViewer
%
% View and export Startle Reflex datasets
%
% DJS (c) 2011

% Last Modified by GUIDE v2.5 17-Feb-2012 00:57:26

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @SRResultsViewer_OpeningFcn, ...
    'gui_OutputFcn',  @SRResultsViewer_OutputFcn, ...
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


% --- Executes just before SRResultsViewer is made visible.
function SRResultsViewer_OpeningFcn(hObject, eventdata, h, varargin) %#ok<INUSL>
% Choose default command line output for SRResultsViewer
h.output = hObject;


h.SETTINGS.datadir  = [];
h.SETTINGS.datasets = [];

% h.regKey = 'HKCU\Software\MATHWORKS\MATLAB\StartleReflex';
guidata(hObject, h);

% sfn = GetRegKey(h.regKey,'rvsettingsfn');
sfn = getpref('StartleReflex','rvsettingsfn',cd);

if ~isempty(sfn)
    set(h.datadir,'String',sfn);
    datadir_Callback(h.datadir,[],h);
end


% --- Outputs from this function are returned to the command line.
function varargout = SRResultsViewer_OutputFcn(hObject, eventdata, handles)  %#ok<INUSL>
varargout{1} = handles.output;








function p = PlotResults(h)
ds = h.CURDATASETS;

dvar = get(h.params,'String');
if isempty(dvar), return; end
dvar = dvar{get(h.params,'Value')};

cfg.dvar = dvar;
cfg.rms_win   = getpref('StartleReflex','rms_win',[1 51]);
cfg.rms_blwin = getpref('StartleReflex','rms_blwin',[-50 0]);

ncol = floor(sqrt(length(ds)));
nrow = ceil(length(ds) / ncol);

delete(get(h.plot_panel,'children'));

m = get(h.view_measure,'String');
m = m{get(h.view_measure,'Value')};

h.CURRESULTS = [];
h.CURUVAR    = [];
h.CURMEASURE = [];
h.MEASURES   = [];

ax = zeros(size(ds));
for i = 1:length(ds)
    SD = ds{i};
    
    [data,measure,uv,idx] = SRAnalysis(SD,cfg);
    
    ax(i) = subplot(nrow,ncol,i,'parent',h.plot_panel);
    
    cfg.uv  = uv;
    cfg.idx = idx;
    if strcmp(m,'Waveforms');
        val = get(h.view_vals,'Value');
        cfg.idx = idx(:,val);
        p(:,i) = SRPlotWaveforms(ax(i),SD,cfg); %#ok<AGROW>
    else
        cfg.measure = measure;
        cfg.plotmeasure = m;
        p(i) = SRPlotResult(ax(i),data,cfg); %#ok<AGROW>
    end
    
    set(p(i),'tag',SD.alias);
    
    title(ax(i),sprintf('%s (%d)',strrep(SD.alias,'_',' '),size(data,1)));
    
    h.CURRESULTS{i} = data;
    h.CURUVAR{i}    = uv;
    h.MEASURES{i}   = measure;
end
h.CURMEASURE = m;



[c,r] = ind2sub([ncol nrow],1:length(ds));
set(ax(r~=nrow),'xticklabel',[]);
set(ax(c~=1),   'yticklabel',[]);

if length(ax) > 1
    y = cell2mat(get(ax,'ylim'));
    set(ax,'ylim',[min(y(:,1)) max(y(:,2))]);
end

set(p,'LineWidth',2,'MarkerFaceColor','b','MarkerEdgeColor','b');

guidata(h.figure1,h);





% ----------- EXPORT DATA -------------
function ExportResult(hObj, h) %#ok<DEFNU,INUSL>
ds = h.CURDATASETS;
r  = h.CURRESULTS;
uv = h.CURUVAR;
cm = h.CURMEASURE;
ms = h.MEASURES;

ef = getpref('StartleReflex','exportfileinfo',{cd,'Data','.xls'});

[fn,pn,fi] = uiputfile( ...
    {'*.mat','MAT-file (*.mat)'; ...
    '*.xls','Excel File (*.xls)'; ...
    '*.csv','Comma-Separated Values (*.csv)'}, ...
    'Save result as',fullfile(ef{1},ef{2}));

if ~fn, return; end


set(gcf,'pointer','watch'); drawnow
for i = 1:length(ds)
    n = [fn(1:end-4) '_' ds{i}.alias fn(end-3:end)];
    f = fullfile(pn,n);
    
    if exist(f,'file')
        bn = questdlg(sprintf('The file ''%s'' already exists.',f), ...
            'File Exists','Overwrite','Skip','Cancel','Skip');
        switch bn
            case 'Skip'
                continue
            case 'Cancel'
                set(gcf,'pointer','arrow');
                return
        end
    end
    
    fprintf('Saving ''%s'' ... ',n);
    
    try
        midx = ismember(ms{i},cm);
        if ~any(midx)
            
            p = cellstr(get(h.params,'String'));
            p = p{get(h.params,'Value')};
            v = get(h.view_vals,'Value');
            ind = [ds{i}.schedule.vals.(p)] == uv{i}(v);
            result = ds{i}.waveform(:,ind);
            values = find(ind);
            measure = 'Waveforms'; %#ok<NASGU>
            
            switch fi
                
                %%% FIX SAVE RAW WAVEFORMS
                case 1 % mat
                    fe = '.mat';
                    save(f,'result','measure','values');
                    
                case 2 % xls
                    % CANNOT WRITE TO XLS WITH EXCEL 2010
                    % NO WORK AROUND AVAILABLE
                    % http://www.mathworks.com/support/solutions/en/data/1-2SJUON/index.html?solution=1-2SJUON
                    fe = '.xls';
                    result = [{'time/trial'}, num2cell(values); ...
                              num2cell(ds{i}.tvec(:)), num2cell(result)];
                    xlswrite(f,result,1,'B3');
                    
                case 3 % csv
                    fe = '.csv';
                    result = [ds{i}.tvec(:) result]; %#ok<AGROW>
                    csvwrite(f,[nan, values; result]);
            end
        else
            result  = squeeze(r{i}(:,midx,:));
            measure = ms{i}{midx}; %#ok<NASGU>
            values  = uv{i};
            
            switch fi
                case 1 % mat
                    fe = '.mat';
                    save(f,'result','measure','values');
                    
                case 2 % xls
                    fe = '.xls';
                    xlswrite(f,[values(:)'; result],1);
                    
                case 3 % csv
                    fe = '.csv';
                    csvwrite(f,[values'; result]);
                    
            end
        end
        
        
        
        fprintf('SUCCESS\n');
    catch %#ok<CTCH>
        fprintf('FAILED ***\n');
    end
end

ef = {pn,fn,fe};

setpref('StartleReflex','exportfileinfo',ef);
set(gcf,'pointer','arrow');



% ------------------ GUI CALLBACKS -----------------
function datasets_Callback(hObj, e, h) %#ok<INUSL,DEFNU>
set(gcf,'pointer','watch'); drawnow

d = h.SETTINGS.datadir;
k = get(hObj,'Value');
x = get(hObj,'String');
x = x(k);

h.CURDATASETS = [];

for i = 1:length(x)
    ds = fullfile(d,x{i});
    
    load(ds);
    
    if i == 1, params = StartleData.schedule.readparams;  end
    
    params = unique([params StartleData.schedule.readparams]);
    
    h.CURDATASETS{i} = StartleData;
end

params(ismember(params,'DataBuffer')) = [];
set(h.params,'Enable','on','String',params);

cfg.dvar = 'SRdB';
cfg.rms_win   = getpref('StartleReflex','rms_win',[1 51]);
cfg.rms_blwin = getpref('StartleReflex','rms_blwin',[-50 0]);
[~,m] = SRAnalysis(StartleData,cfg);
set(h.view_measure,'Enable','on','String',['Waveforms' m]);

guidata(h.figure1,h);

PlotResults(h);

set(gcf,'pointer','arrow');

function datadir_Callback(hObj, e, h) %#ok<INUSL>
set(gcf,'pointer','watch'); drawnow

d = get(hObj,'String');

if isempty(d), return; end

if d(end) ~= '\', d(end+1) = '\'; end

h.SETTINGS.datadir  = d;

ds = dir([d,'*.mat']);

if isempty(ds)
    set(h.datasets,'Value',1,'String',[]);
    h.SETTINGS.datasets = [];
    guidata(h.figure1,h);
    set(gcf,'pointer','arrow');
    return
end
setpref('StartleReflex','rvsettingsfn',d);

fn = {ds.name};

r = false(size(fn));
for i = 1:length(fn)
    x = whos('-file',[d fn{i}],'StartleData');
    r(i) = isempty(x);
end
fn(r) = [];

set(h.datasets,'Enable','on','String',fn);

h.SETTINGS.datasets = fn;


guidata(h.figure1,h);

set(gcf,'pointer','arrow');


function locate_datadir_Callback(hObj, e, h) %#ok<DEFNU,INUSL>
sfn = getpref('StartleReflex','rvsettingsfn',cd);
d = uigetdir(sfn,'Locate dataset directory');

if ~d, return; end

d = [d '\'];

set(h.datadir,'Enable','on','String',d);

datadir_Callback(h.datadir,[],h);

setpref('StartleReflex','rvsettingsfn',d);





function params_Callback(hObj, e, h) %#ok<INUSL>
rv = h.CURDATASETS{1}.schedule.vals;

dvar = get(h.params,'String');
if isempty(dvar), return; end
dvar = dvar{get(h.params,'Value')};

uv = unique([rv.(dvar)]);

set(h.view_vals,'Value',1,'String',uv);
PlotResults(h);


function view_measure_Callback(hObj, e, h) %#ok<INUSL,DEFNU>
v = get(hObj,'Value');
s = cellstr(get(hObj,'String'));

if isequal(s{v},'Waveforms')
    set(h.view_vals,'Enable','on');
else
    set(h.view_vals,'Enable','off');
end

PlotResults(h);


function send_to_workspace_Callback(hObj, e, h) %#ok<INUSL,DEFNU>
ds = h.CURDATASETS;
r  = h.CURRESULTS;
uv = h.CURUVAR;
cm = h.CURMEASURE;
ms = h.MEASURES;

varname = getpref('StartleReflex','varname','data');

varname = inputdlg('Enter variable name:','',1,{varname});

varname = char(varname);

if isempty(varname), return; end

if isequal(cm,'Waveforms')
    p = cellstr(get(h.params,'String'));
    p = p{get(h.params,'Value')};
    v = get(h.view_vals,'Value');
    for i = 1:length(ds)
        ind = [ds{i}.schedule.vals.(p)] == uv{i}(v);
        result(i).waveform = ds{i}.waveform(:,ind);  %#ok<AGROW>
        result(i).timevector = ds{i}.tvec;  %#ok<AGROW>
        result(i).alias = ds{i}.alias;  %#ok<AGROW>
        result(i).date  = ds{i}.date;  %#ok<AGROW>
        result(i).var   = uv{i}(v);  %#ok<AGROW>
    end
else
    for i = 1:length(ds)
        midx = ismember(ms{i},cm);
        result(i).values = squeeze(r{i}(:,midx,:))'; %#ok<AGROW>
        result(i).ivars = uv{i};  %#ok<AGROW>
        result(i).alias = ds{i}.alias;  %#ok<AGROW>
        result(i).date  = ds{i}.date;  %#ok<AGROW>
    end
end

if length(result) == 1, result = result{1}; end

assignin('base',varname,result);
evalin('base',sprintf('whos %s',varname))

setpref('StartleReflex','varname',varname);



function mnu_settings_awindow_Callback(hObj, e, h) %#ok<INUSL,DEFNU>
rms_win   = getpref('StartleReflex','rms_win',[1 51]);
rms_blwin = getpref('StartleReflex','rms_blwin',[-50 0]);

r = inputdlg({'Baseline window:','Analysis window:'},'Analysis Window', ...
    1,{num2str(rms_win), num2str(rms_blwin)});

if isempty(r), return; end

setpref('StartleReflex',{'rms_win','rms_blwin'},{str2num(r{1}),str2num(r{2})}); %#ok<ST2NM>

params_Callback(h.params, [], h);

