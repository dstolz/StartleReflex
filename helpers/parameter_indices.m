function ind = parameter_indices(S)
% ind = parameter_indices(schedule)
% 
% Returns a structure, ind, with the locations of parameters in writeparams


for w = S.writeparams
    ind.(char(w)) = ismember(S.writeparams,char(w));
end