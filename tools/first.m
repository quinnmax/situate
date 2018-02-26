function z = first( input )
% returns the first element of an array
    if isempty(input)
        z = [];
    elseif iscell(input)
        z = input{1};
    else
        z = input(1);
    end
end