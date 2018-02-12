
function pool_out = clear_and_refill( pool_in, varargin )

    % pool_out = clear_and_refill( pool_in, threshold, fill_to_size )

    threshold = varargin{1};
    fill_to_size = varargin{2};

    pool_out = pool_in;
    
    pool_out = pool_out( [pool_out.urgency] >= threshold );
    pool_out = [ pool_out repmat(situate.agent_initialize(),1,fill_to_size-length(pool_out)) ];
    
end
