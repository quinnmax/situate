

% make gt model

dims = 2;
k = 2;

mu = [0 0; 5 5];

Sigma = [];
Sigma(:,:,1) =   1 * eye(dims);
Sigma(:,:,2) =  .5 * eye(dims);

pi = [.9, .1];

model_gt.mu = mu;
model_gt.Sigma = Sigma;
model_gt.pi = pi;


% sample data
x1 = gmm_sample( model_gt, 10000 );
figure;
plot( x1(:,1), x1(:,2), '.' );
xlim([-4 8]);
ylim([-4 8]);


% model data
temp = gmm_fit( x1, k );
model_est = [];
model_est.mu = cat(1,temp(:).mu);
model_est.Sigma = cat(3,temp(:).sigma);
model_est.pi = cat(1,temp(:).pi);


% generate data from the model
[x2, densities, responsibilities ] = gmm_sample( model_est, 10000 );
color = [responsibilities(:,1), zeros(size(x2,1),1), responsibilities(:,2)];
color = color ./ repmat( max(color), size( color,1), 1 );
color(isnan(color)) = 0;
figure;
ni = 1;
plot( x2(ni,1), x2(ni,2), '.', 'Color', color(ni,:) );
hold on;
for ni = 2:1000
    plot( x2(ni,1), x2(ni,2), '.', 'Color', color(ni,:) );
end
xlim([-4 8]);
ylim([-4 8]);


% condition given some data
want_inds  = logical([1 0]);
known_inds = logical([0 1]);
known_vals = [5];
model_conditional = gmm_condition( model_est, want_inds, known_inds, known_vals );


% view resulting dist
[x3, densities, responsibilities ] = gmm_sample( model_conditional, 10000 );
figure;
hist(x3,20)
xlim([-4 8]);

    

















