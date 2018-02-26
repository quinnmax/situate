function z = last( input )
% returns the last element of an array
    if isempty(input)
        z = [];
    elseif iscell(input)
        z = input{end};
    else
        z = input(end);
    end
end