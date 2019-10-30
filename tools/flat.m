function out = flat(in,dim)
% out = flat(in,[dim]);
%   if dim=1, it will be reshaped to a single row; (default)
%   if dim=2, it will be reshaped to a single column;
%   if dim=3, it will be singleton in row and column and data will be in the 3rd dim
%   that's it though.

    if nargin < 2
        dim = 1;
    end

    switch dim
        case 1
            out = reshape(in,[],1);
        case 2
            out = reshape(in,1,[]);
        case 3
            out = reshape(in,[],[],1);
        otherwise
            error('this is a fragile function my friend');
    end
    
end
