function h = sr_prepulse_sequence(h)
% h = sr_prepulse_sequence(h)
% 
% Custom function creates a buffer for playback from the RPvds circuit

% sampling rate???  
Fs = h.SFreq(h.experiment.STIMMODS(1));

sch = h.schedule;
trials = sch.trials;


% ind contains a structure with locations of parameters in 'trials' columns
ind = parameter_indices(sch);



% copy trials row for curren t schedule index
T = trials(h.schidx,:);
nstd = T{ind.stdCount};
freq = T{ind.stdFreq};

% TODO: CONVERT TIME (ms) TO SAMPLES AT STIMULUS MODULE SAMPLING RATE
dur  = T{ind.PPDuration};
isi  = T{ind.stdISI};

dur = dur ./ 1000; % ms -> sec
isi = isi ./ 1000; % ms -> sec
isisamps = round(Fs.*isi);

% generate standard tones
y = [gen_tone(Fs,freq,dur), zeros(1,isisamps)];
y = repmat(y,1,nstd);


% generate deviant tone
y = [y, gen_tone(Fs,T{ind.devFreq},dur)];

% add the buffer to the trials matrix
sch.trials{h.schidx,ind.buffer} = y;

h.schedule = sch;


function y = gen_tone(Fs,freq,dur)
rftime = .005; % seconds
rfsamps = round(Fs*rftime);
rfsamps = rfsamps + rem(rfsamps,2);
midpt = rfsamps/2;
g = hann(rfsamps)'; % gate

si = 1/Fs;
tvec = 0:si:dur-si;

y = sin(2.*pi.*freq.*tvec);

g = [g(1:midpt), ones(1,length(y)-length(g)), g(midpt+1:end)];
y = y.*g;




