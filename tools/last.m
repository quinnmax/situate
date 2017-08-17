function z = last( input )
% last returns the last element of an array
    if isempty(input)
        z = 0;
    elseif iscell(input)
        z = input{end};
    else
        z = input(end);
    end
end