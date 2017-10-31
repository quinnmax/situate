function pool_out = clear_low_urgency( pool_in, cutoff ) 
    
    % pool_out = clear_low_urgency( pool_in, cutoff ) ;
    %
    % pool_out = pool_in( [pool_in.urgency] >= cutoff );

    pool_out = pool_in( [pool_in.urgency] >= cutoff );
    
end