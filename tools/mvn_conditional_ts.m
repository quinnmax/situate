




function mvn_conditional_ts()

    % this shows how to take a high dimensional normal distribution,
    % specify some known values, generate new conditional mv normal
    % distributions, and then sample from them if desired.
    %
    % the parameters for the resulting conditional distributions are mu_bar
    % and Sigma_bar below. 
    %
    % conditional normal distribution example
    % https://en.wikipedia.org/wiki/Multivariate_normal_distribution#Conditional_distributions

    mu_gt = [0 0 0];
    Sigma_gt = [1 .9 0; .9 1 .5; 0 .5 2];
    
    known_dimensions = [1 0 0];
    known_values = [2 0 0];
    
    data_1 = mvnrnd( mu_gt, Sigma_gt, 2000 );
    mu    = mean( data_1 );
    Sigma = cov(  data_1 );
    
    [mu_bar, Sigma_bar] = mvn_conditional( mu, Sigma, known_dimensions, known_values );
    
    
    % sample from the new, conditional distribution
    n = 50;
    data_2 = repmat( reshape(known_values,1,[]), n, 1 );
    data_2(:,~known_dimensions) = mvnrnd(mu_bar,Sigma_bar,n);
    
    
    
    figure('position',[-500 0 1200 600]);

    subplot(1,3,1);
    plot(data_1(:,1),data_1(:,2),'.b');
    hold on
    plot(data_2(:,1),data_2(:,2),'.r');
    xlabel('dim 1'); ylabel('dim 2');

    subplot(1,3,2);
    plot(data_1(:,1),data_1(:,3),'.b');
    hold on
    plot(data_2(:,1),data_2(:,3),'.r');
    xlabel('dim 1'); ylabel('dim 3');

    subplot(1,3,3);
    plot(data_1(:,2),data_1(:,3),'.b');
    hold on
    plot(data_2(:,2),data_2(:,3),'.r');
    xlabel('dim 2'); ylabel('dim 3');

    hold off;


    figure()
    plot3(data_1(:,1),data_1(:,2),data_1(:,3),'.b');
    hold on;
    plot3(data_2(:,1),data_2(:,2),data_2(:,3),'.r');
    hold off;
    

end





