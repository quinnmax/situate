function a = scout_post_eval_rule( a, threshold )
    
    % if good support, return the agent to the pool with scaled urgency

    if ~exist('threshold','var')
        threshold = .25;
    end
    
    if a.support.internal > threshold
        a.urgency = a.support.internal;
    else
        a = [];
    end

end