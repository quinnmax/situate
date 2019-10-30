function out = rmse(a,b)

a = reshape(a,1,[]);
b = reshape(b,1,[]);

out = sqrt( mean( (a-b).^2 ) );

end