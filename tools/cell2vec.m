function out = cell2vec(x)

     temp = cellfun( @(y) reshape(y,1,[]), x, 'uniformoutput', false );
     out = [temp{:}];
     
end