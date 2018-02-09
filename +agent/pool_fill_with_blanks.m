function pool_out = fill_with_blanks( pool_in, fill_to_size )

    % pool_out = fill_with_blanks( pool_in, fill_to_size );
    %
    %   pool_out = [ pool_in repmat(situate.agent_initialize(),1,fill_to_size-length(pool_in)) ];
    
    pool_out = [ pool_in repmat(situate.agent_initialize(),1,fill_to_size-length(pool_in)) ];
    
end