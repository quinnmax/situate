


close all



num_iter = 50;
repeated_trials = 10;



% make gt model
dims    = 7;
k_gt    = 4;

% parameter for fitting
k_est   = 3;

mu = 10*(rand(k_gt,dims)-1);
Sigma = zeros(dims,dims,k_gt);
Sigma(logical(repmat(eye(dims),[1,1,k_gt]))) = .1 + 1*rand(1,dims*k_gt);

pi = rand(1,k_gt) + .1;
pi = pi/sum(pi);

model_gt.mu    = mu;
model_gt.Sigma = Sigma;
model_gt.pi    = pi;



% sample data
x1 = gmm_sample( model_gt, 1000 );

% viz sampled data
figure;
plotmatrix(x1);
title('data from gt dist');



% model data
[model_est, log_lik_per_iter, alt_model_est] = gmm_fit( x1, k_est, num_iter, repeated_trials );



% view log_lik over iterations
figure; 
plot( 1:num_iter, log_lik_per_iter); xlabel('iteration'); ylabel('log likelihood');
title('log likelihood during fitting');



% generate and visualize data from the estimate
[x2, densities, responsibilities ] = gmm_sample( model_est, 1000 );
color = [responsibilities(:,1), zeros(size(x2,1),1), responsibilities(:,2)];
color = color ./ repmat( max(color), size( color,1), 1 );
color(isnan(color)) = 0;
figure;
ni = 1;
plotmatrix(x2);
title('data from modeled dist');







use_viz_stuff = true;
if use_viz_stuff
    
% demo viz code 

    % visualize model
    figure;
    
    % first, the 2d thing
    subplot(3,1,1);

    viz_cols = [1 2];
    viz_n = length(viz_cols);
    
    % marginalize to viz cols
    model_viz = gmm_condition( model_est, viz_cols, [], [] );
    
    per_dim_min =  inf(viz_n,1);
    per_dim_max = -inf(viz_n,1);
    for ki = 1:k_est
        per_dim_min = min( per_dim_min, model_viz.mu(ki,:)' - 3*sqrt(abs(diag(model_viz.Sigma(:,:,ki) ) ) ) );
        per_dim_max = max( per_dim_max, model_viz.mu(ki,:)' + 3*sqrt(abs(diag(model_viz.Sigma(:,:,ki) ) ) ) );
    end
    output_rows = 100;
    output_cols = 100;
    [X,Y] = meshgrid( linspace( per_dim_min(1),per_dim_max(1), output_cols), linspace( per_dim_min(2),per_dim_max(2), output_rows) );
    Z_flat = gmmpdf( [X(:) Y(:)], model_viz );
    Z = reshape( Z_flat, size(X) );
    Z = Z(end:-1:1,:);
    imshow(Z,[]);
    xlabel('dim 1');
    xlabel('dim 2');

    % marginalize to size col
    subplot(3,1,2);
    
    target_dim = 1;
    model_viz = gmm_condition( model_est, target_dim, [], [] );
    cur_x_min = inf;
    cur_x_max = -inf;
    for ki = 1:k_est
        cur_x_min = min( cur_x_min, model_viz.mu(ki) - 3*sqrt(model_viz.Sigma(1,1,ki)) );
        cur_x_max = max( cur_x_max, model_viz.mu(ki) + 3*sqrt(model_viz.Sigma(1,1,ki)) );
    end
    cur_x_vals = linspace(cur_x_min,cur_x_max,100);
    y = gmmpdf( cur_x_vals, model_viz );
    plot( cur_x_vals, y );
    xlabel( 'dim 1' );
    
    % then marginalized for a particular dimension
    subplot(3,1,3);
    
    target_dim = 2;
    model_viz = gmm_condition( model_est, target_dim, [], [] );
    cur_x_min = inf;
    cur_x_max = -inf;
    for ki = 1:k_est
        cur_x_min = min( cur_x_min, model_viz.mu(ki) - 3*sqrt(model_viz.Sigma(1,1,ki)) );
        cur_x_max = max( cur_x_max, model_viz.mu(ki) + 3*sqrt(model_viz.Sigma(1,1,ki)) );
    end
    cur_x_vals = linspace(cur_x_min,cur_x_max,100);
    y = gmmpdf( cur_x_vals, model_viz );
    plot( cur_x_vals, y );
    xlabel( 'dim 2' );

end
    
    





% condition given some data
want_inds    = true(1,dims);
want_inds(1) = false;

known_inds = ~want_inds;
known_vals = zeros(1,sum(known_inds));
model_conditional = gmm_condition( model_est, want_inds, known_inds, known_vals );



% view resulting dist
[x3, densities, responsibilities ] = gmm_sample( model_conditional, 1000 );
figure;
plotmatrix(x3);
title('conditioned dist');

    

















