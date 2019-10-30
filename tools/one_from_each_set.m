function out = one_from_each_set( varargin )
% out = one_from_each_set( [0,1], [1,2], [3] );
% out = one_from_each_set( {[0,1], [1,2], [3]} );
%
% out =
% 
%      0     1     3
%      0     2     3
%      1     1     3
%      1     2     3

    if numel(varargin) == 1 && iscell(varargin{1})
        x = varargin{1};
    else
        x = varargin;
    end

    for xi = 1:numel(x)
        if size(x{xi},2)>1, x{xi} = x{xi}'; end
        x{xi} = unique( x{xi} );
    end

    out = [];
    for xi = 1:numel(x)
        out = [ sortrows(repmat(out,numel(x{xi}),1)) repmat(x{xi},max(1,size(out,1)),1)];
    end

end
    
    
    




