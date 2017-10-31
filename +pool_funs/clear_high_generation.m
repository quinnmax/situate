function pool_out = clear_high_generation( pool_in, cutoff ) 
    
    % pool_out = clear_high_generation( pool_in, cutoff ) ;
    %
    % pool_out = pool_in( [pool_in.generation] < cutoff );

    pool_out = pool_in( [pool_in.generation] < cutoff );
    
end