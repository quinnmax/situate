function progress(i,n,message)

    % progress( i, n, [message] );
    % prints out:
    % message i/n
    
    persistent progress_width;
    
    if ~isempty(progress_width)
        backspaces = sprintf(repmat('\b',1,progress_width));
    else
        backspaces = '';
    end
    
    if ~exist('message','var')
        message = [];
    end
    
    progress_string = sprintf(['\n\n' message ' %d / %d\n\n'],i,n);
    progress_width = length(progress_string);
    fprintf([backspaces progress_string]);
    
    if i == n
        progress_width = [];
        clear progress_width;
        fprintf('\n');
    end
    
%     persistent h;
%     if ishandle(h); close(h); end;
%     h = msgbox( progress_string );
    
end