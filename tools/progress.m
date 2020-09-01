function progress(i,n,message)

    % progress( i, n, [message] );
    % prints out:
    % message i/n
    %
    
    
    persistent progress_width;
    persistent start_time
    
    % erase the previous message
    if ~isempty(progress_width)
        backspaces = sprintf(repmat('\b',1,progress_width));
    else
        backspaces = '';
    end

    if isempty(start_time)
        start_time = tic;
    end
    
    if ~exist('message','var')
        message = [];
    end
    
    elapsed_time = (tic - start_time);
    est_total_time = n * (elapsed_time / i);
    est_time_remaining = est_total_time - elapsed_time;
    est_time_remaining_s = est_time_remaining / 1000000000;
   
    progress_string = sprintf([message ' %d / %d   t:%d(s) \n'],i,n, est_time_remaining_s);
    progress_width = length(progress_string);
    fprintf([backspaces progress_string]);
    
    if i == n
        progress_width = [];
        clear progress_width;
        clear start_time;
    end
    
end

%time so far / total time = i / n


