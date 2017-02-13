function y = row2cell( x )

    y = mat2cell(x,ones(size(x,1),1),size(x,2));
    
end