function [response, differences] = isequal_struct( a, b )

    % [response, differences] = isequal_struct( a, b );
    %   response 1: equal
    %   response multiple of 2: equal if you ignore frozen variables in anonymous functions
    %   response multiple of 3: equal if you ignore Nan
    %   response 0: not equal
    %   differences: cell array of explanations of differences and possible differences

    response = 1;
    differences = {};
    
    a_not_b_fields = setdiff( fields(a), fields(b) );
    b_not_a_fields = setdiff( fields(b), fields(a) );
    shared_fields  = intersect( fields(a), fields(b) );
    
    if ~isempty(a_not_b_fields) || ~isempty(b_not_a_fields)
        response = 0;
        differences{end+1} = fprintf( 'fields do NOT match, a not b fields: %s', a_not_b_fields{:} );
        differences{end+1} = fprintf( 'fields do NOT match, b not a fields: %s', b_not_a_fields{:} );
        return;
    end
    
    for fi = 1:length(shared_fields)

        if isstruct( a.(shared_fields{fi}) )
        % recursive isequal_struct call
            
            [sub_resp, sub_diff] = isequal_struct( a.(shared_fields{fi}), b.(shared_fields{fi}) );
            if ~sub_resp
                differences{end+1} = [shared_fields{fi} ':' sub_diff{1}];
                response = 0; 
            end
            
        elseif isequal( class( a.(shared_fields{fi}) ), 'function_handle' )
        % anonymous function handles equalish
            
            sub_resp = strcmp( func2str( a.(shared_fields{fi}) ), func2str( b.(shared_fields{fi}) ) );
            if ~sub_resp
                differences{end+1} = [shared_fields{fi} ' are NOT equal'];
                response = 0;
            else
                differences{end+1} = [shared_fields{fi} ' MAY be equal (if their frozen vars are equal)'];
                response = response * 2;
            end
            
        elseif isnumeric( class( a.(shared_fields{fi}) ) ) && isequal( isnan(a.(shared_fields{fi})), isnan(b.(shared_fields{fi})) ) 
        % nan equalish
            
            temp_a = a.(shared_fields{fi}); temp_a = temp_a(~isnan(temp_a));
            temp_b = b.(shared_fields{fi}); temp_b = temp_b(~isnan(temp_a));
            sub_resp = isequal( temp_a, temp_b );
            if ~sub_resp
                differences{end+1} = [shared_fields{fi} ' are NOT equal'];
                response = 0;
            else
                differences{end+1} = [shared_fields{fi} ' MAY be equal (if you don''t mind Nans'];
                response = response * 3;
            end
            
        else
        % the rest
            
            sub_resp = isequal( a.(shared_fields{fi}), b.(shared_fields{fi}) );
            if ~sub_resp
                response = 0;
                differences{end+1} = [shared_fields{fi} ' are NOT equal'];
            end
            
        end

    end
    
end
