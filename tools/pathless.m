function output = pathless( input )

    if iscell(input)
        output = cellfun( @pathless, input, 'UniformOutput', false );
    elseif ischar(input)
        output = input(last(strfind(input,filesep))+1:end);
    else
        error('dunno');
    end
    
end

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