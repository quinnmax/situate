function d_json = jsondecode_file( fname_in )

    % struct = jsondecode_file( fname_in )
    %
    % diff here is that it scrubs out comments

    raw_text = fileread(fname_in);
    text_linesplit = strsplit( raw_text, '\n' );
    text_linesplit = cellfun( @strip, text_linesplit, 'UniformOutput', false );
    comment_positions = cellfun( @(x) strfind(x,'//'), text_linesplit, 'UniformOutput', false );
    for li = 1:length(text_linesplit)
        if ~isempty(comment_positions{li})
            text_linesplit{li} = text_linesplit{li}(1:comment_positions{li}-1);
        end
    end
    lines_keep = cellfun( @(x) ~isempty(strip(x)), text_linesplit);
    text_cleaned = strjoin( text_linesplit(lines_keep), '\n');
    d_json = jsondecode(text_cleaned);
    
end