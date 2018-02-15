function result = parameters_struct_validate( p )

    if numel(p) > 1
        result = arrayfun( @situate.parameters_struct_validate, p );
    elseif iscell(p)
        result = cellfun( @situate.parameters_struct_validate, p );
    end
    
    warning('check that functions exist as defined');
    
end