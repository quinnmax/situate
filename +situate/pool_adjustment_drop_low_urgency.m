function pool_out = pool_adjustment_drop_low_urgency( pool_in, threshold )
% pool_out = pool_adjustment_drop_low_urgency( pool_in, threshold )
%
% removes agents with urgency < threshold

    if ~exist('threshold','var')
        theshold = .5; 
    end

    pool_out = pool_in( [pool_in.urgency] >= threshold );
    
end