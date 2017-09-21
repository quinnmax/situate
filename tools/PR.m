function [precision, recall, thresholds] = PR( d_vars, labels )
    %
    % [precision, recall, thresholds] = PR( d_vars, labels )
    %
    % if direction is (+), then a high d_val is associated with targets [default]
    % if direction is (-), then a low d_val is associated with targets
    % if direction is (0), then ROC will make a charitable assumption
    %   direction selected using means of dvars only, not automatically > .5
    
    direction = 1;
    d_tar_in = d_vars(eq(labels,1));
    d_non_in = d_vars(eq(labels,0));
    
    % set up our thresholds
    
        if direction == 0
            % direction = 1;
            if mean(d_tar_in) > mean(d_non_in)
                direction = 1;
            else
                direction = -1;
            end
        end

        d_tar = direction * d_tar_in(:)';
        d_non = direction * d_non_in(:)';

        % % fixed number of steps threshold
        % dsteps = 200;
        % d_min = min([ d_tar d_non ]);
        % d_max = max([ d_tar d_non ]);
        % range = d_max - d_min;
        % thresholds = linspace( d_max + range/steps, d_min - range/steps, steps );

        % a threshold for every unique value in dvars
        uv = unique(d_vars(:));
        thresholds = [min(uv)-1; uv(1:end-1) + diff(uv)/2 ];
        steps = length(thresholds);
        
        while steps > 10000
            thresholds = thresholds([1:2:end-1, end]);
            steps = length(thresholds);
        end
        
        
        
    % calculate TPR and FPR for each threshold
    
        precision = zeros(1,steps);
        recall = zeros(1,steps);
        for i = 1:steps
            cur_thresh = thresholds(i);
            TPs = sum( gt(d_tar, cur_thresh) );
            FPs = sum( gt(d_non, cur_thresh) );
            
            precision(i) = TPs ./ (TPs + FPs);
            recall(i) = TPs / length(d_tar);
        end
    
        
   

            
end