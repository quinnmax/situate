function [counts,bin_edges_rows,bin_edges_cols] = histomap( data, in1, in2 )

    % [counts,bin_edges_rows,bin_edges_cols] = histomap( data, n );
    %   n defaults to 10
    % [counts,bin_edges_rows,bin_edges_cols] = histomap( data, rows, cols );
    %   rows defaults to 10
    %   cols defaults to rows
    % [counts,bin_edges_rows,bin_edges_cols] = histomap( data, bin_deges_rows, bin_edges_cols );
    %
    % if displaying as an image, keep in mind that col 1, which you might want to be x, is the row
    % variable. 
    % try: imshow( n(:,end:-1:1)', [] )
    
    
    if nargin<2
        in1 = 10;
    end
    
    
    if nargin < 3
        in2 = in1;
    end
    
    
    if numel(in1) > 1
        bin_edges_rows = in1;
        rows = numel(bin_edges_rows);
    else
        rows = in1 + 1;
        min_row = min(data(:,1));
        max_row = max(data(:,1));
        bin_edges_rows = linspace( min_row, max_row, rows);
        
    end
    
    
    if numel(in2) > 1
        bin_edges_cols = in2;
        cols = numel(bin_edges_cols);
    else
        cols = in2 + 1;
        min_col = min(data(:,2));
        max_col = max(data(:,2));
        bin_edges_cols = linspace( min_col, max_col, cols);
    end
    
    
    [~,row_ind] = max( data(:,1) <= bin_edges_rows(2:end), [], 2 );
    [~,col_ind] = max( data(:,2) <= bin_edges_cols(2:end), [], 2 );
    
    
    counts = zeros(rows,cols);
    for i = 1:size(data,1)
        counts(row_ind(i),col_ind(i)) = counts(row_ind(i),col_ind(i)) + 1;
    end
    
    counts = counts(1:end-1,1:end-1);
    
    
end