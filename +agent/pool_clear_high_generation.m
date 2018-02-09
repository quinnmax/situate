function pool_out = clear_high_generation( pool_in, varargin ) 
    
    % pool_out = clear_high_generation( pool_in, cutoff ) ;
    %
    % pool_out = pool_in( [pool_in.generation] < cutoff );

    cutoff = varargin{1};
    
    pool_out = pool_in( [pool_in.generation] < cutoff );
    
end