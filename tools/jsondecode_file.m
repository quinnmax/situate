


function d_json = jsondecode_file( fname_in )

    % struct = jsondecode_file( fname_in )
    %
    % diff here is that it scrubs out comments

    raw_text = fileread(fname_in);
    
    d_json = jsondecode( comments_removed( raw_text ) );
    
end



function cleaned = comments_removed( in )


    cleaned = in;

    
    % remove block comments

    block_start_str = '/*';
    block_end_str   = '*/';
    
    comment_start = strfind( cleaned, block_start_str );
    while ~isempty( comment_start )
        comment_end = strfind( cleaned, block_end_str);
        comment_end = comment_end( comment_end > comment_start(1) );
        cleaned(comment_start(1):comment_end(1)+1) = [];
        comment_start = strfind( cleaned, block_start_str );
    end
    
    
    % remove line comments
    
    line_comment_str = '//';
    
    line_cells = strsplit(cleaned,'\n');
    
    comment_start = cellfun( @(x) strfind(x,line_comment_str), line_cells, 'UniformOutput', false );
    for li = 1:length(line_cells)
        if ~isempty(comment_start{li})
            line_cells{li} = line_cells{li}(1:comment_start{li}-1);
        end
    end
    lines_keep = cellfun( @(x) ~isempty(strtrim(x)), line_cells);
    
    
    cleaned = strjoin( line_cells(lines_keep), '\n');
    
    
end

    

