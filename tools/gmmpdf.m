function output = gmmpdf( input, varargin )
% output = gmmpdf( input, mu, Sigma, pi )
% output = gmmpdf( input, struct )
%   where struct has mu, Sigma, pi

    if length(varargin) == 1 && isstruct(varargin{1})
        mu = varargin{1}.mu;
        Sigma = varargin{1}.Sigma;
        pi = varargin{1}.pi;
    elseif length(varargin) == 3
        mu = varargin{1};
        Sigma = varargin{2};
        pi = varargin{3};
    end
    
    k = length(pi);
    temp_dims = size(mu);
    temp_dims( find(eq(temp_dims,k),1,'first') ) = [];
    num_dims = temp_dims;
    if numel(input) == numel(mu)
        n = 1;
    else
        temp_n = size(input);
        temp_n( find(eq(temp_n,num_dims),1,'first') ) = [];
        n = temp_n;
    end
    
    % check shape
    input = reshape(input,n,num_dims);
   
    px = zeros(n,k);
    for ki = 1:k
        px(:,ki) = repmat( pi(ki),n,1) .* mvnpdf( input, mu(ki,:), Sigma(:,:,ki) );
    end
    output = sum(px,2);
    
end
    
    
    