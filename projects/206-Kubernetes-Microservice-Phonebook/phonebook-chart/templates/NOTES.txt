Thank you for installing {{ .Chart.Name }}.

Your release is named {{ .Release.Name }}.

To learn more about the release, try:

  $ helm status {{ .Release.Name }}
  $ helm get all {{ .Release.Name }}

To use own images execute as below:

helm upgrade --install phonebook-app phonebook-repo/phonebook-chart --set webserver_image=<image-name> --set resultserver_image=<image-name>