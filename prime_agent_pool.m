function [primed_boxes_r0rfc0cf, primed_agent_pool] = prime_agent_pool( im_size )
% [primed_agent_pool] = prime_agent_pool( im_size )

    linear_scaling_factor = sqrt(im_size(1)*im_size(2));
    box_sizes = round(linear_scaling_factor * [.2 .4 .6]);
    primed_boxes_r0rfc0cf = zeros(0,4);
    for bi = 1:length(box_sizes)
        
        d = box_sizes(bi);
        s = d/2;
        
        rcs = linspace( d/2, im_size(1)-d/2, round(im_size(1)/s) );
        r0s = floor( rcs - d/2 ) + 1;
        rfs = r0s + d - 1;

        ccs = linspace( d/2, im_size(2)-d/2, round(im_size(2)/s) );
        c0s = floor( ccs - d/2 ) + 1;
        cfs = c0s + d - 1;

        block = [sort(repmat( r0s', length(c0s), 1 )) sort(repmat( rfs', length(c0s), 1 )) repmat( c0s', length(r0s), 1 ) repmat( cfs', length(r0s), 1 )];
        
        primed_boxes_r0rfc0cf(end+1:end+size(block,1),:) = block;
        
    end
    
    agent = situate.agent_initialize();
    agent.history = 'primed';
    primed_agent_pool = repmat(agent,size(primed_boxes_r0rfc0cf,1),1);
    for ai = 1:length(primed_agent_pool)
        primed_agent_pool(ai).box.r0rfc0cf = primed_boxes_r0rfc0cf(ai,:);
        primed_agent_pool(ai).urgency = 1;
    end
    
end
       

    



