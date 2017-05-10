function z = last( input )
    if isempty(input)
        z = 0;
    elseif iscell(input)
        z = input{end};
    else
        z = input(end);
    end
end