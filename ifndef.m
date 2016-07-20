

function wasnt_given = ifndef( var_name, default_value )
%
% wasnt_given = ifndef( var_name, default_value );
%
%   if the variable isn't defined (wasn't passed in, was passed in empty)
%
%   then create the variable and assign it the value in default_value (in the
%   calling namespace)
%
%   wasn't given is a boolean indicating whether anything was assigned
    
    call_to_check_var = ['( ~exist(''' var_name ''',''var'') || isempty(' var_name '));'];
    wasnt_given = evalin( 'caller', call_to_check_var );
    
    if wasnt_given; 
        assignin( 'caller', var_name, default_value ); 
    end;
    
end