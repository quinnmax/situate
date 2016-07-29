function new_a = map( a, func, isArray )
%MAP The functional map operation on a single cell array.
    if nargin == 2
        isArray = false;
    end
    if ~iscell(a)
        new_a = arrayfun(func, a, 'UniformOutput', isArray);
    else
        new_a = cellfun(func, a, 'UniformOutput', isArray);
    end

