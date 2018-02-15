function pool_out = pool_clear_low_urgency( pool_in, varargin ) 
    
    % pool_out = pool_clear_low_urgency( pool_in, cutoff ) ;
    %
    % pool_out = pool_in( [pool_in.urgency] >= cutoff );
    
    cutoff = varargin{1};

    pool_out = pool_in( [pool_in.urgency] >= cutoff );
    
end