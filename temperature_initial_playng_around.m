
% temperature
%
% this script just demonstrates how the mixing coefficient and using
% different distributions works
%
% we'll have two variables that we want to optimize, and a shared global
% temp

x_prior = [];
x_prior.min = -5;
x_prior.max =  5;
x_prior.sample = @() (x_prior.max - x_prior.min) * rand(1,1) + x_prior.min;

x_conditioned = [];
x_conditioned.mu = 0;
x_conditioned.sigma = 1;
x_conditioned.sample = @() x_conditioned.mu + x_conditioned.sigma * randn(1,1);


num_samples = 10000;
mixing_coeffs = [0 .1 .25 .5 .75 .9 1];
record = zeros(length(mixing_coeffs),num_samples);

for mci = 1:length(mixing_coeffs)
for si  = 1:num_samples
    
    if rand() > mixing_coeffs(mci)
        record(mci,si) = x_prior.sample();
    else
        record(mci,si) = x_conditioned.sample();
    end
    
end
end

figure;
for mci = 1:length(mixing_coeffs)
    subplot(length(mixing_coeffs),1,mci)
    hist(record(mci,:),50);
end










