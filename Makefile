dev: dev-release upload deploy

dev-release:
	bosh create-release --force

upload:
	bosh upload-release

deploy:
	bosh -d net-checks deploy manifest.yml -l tests.yml

clean:
	rm -rf dev_releases .dev_builds
