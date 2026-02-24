# Service Fusion API Documentation

> **Extracted from:** https://docs.servicefusion.com/#/docs/summary
> **Base URL:** `https://api.servicefusion.com/{version}`
> **Version:** v1
> **Protocols:** https
> **Media Type:** application/json
> **Date extracted:** 2026-02-24

## Documentation

### Getting Started

# Getting Started
The Service Fusion API allows you to programmatically access data stored in your Service Fusion account with ease.

1. You need a valid access token to send requests to the API endpoints. To get your access token see
the [authentication documentation](/v1/#/docs/documentation-1).
2. The API has an access [rate limit](/v1/#/docs/documentation-2) applied to it.
3. The Service Fusion API will only respond to secure communications done over HTTPS. HTTP requests will be sent
a `301` redirect to corresponding HTTPS resources.
4. The request format is controlled by the header `Content-Type` (if not specified, then `application/json` will be used).
The following headers are currently supported:
  - `application/json` - [JSON format](https://en.wikipedia.org/wiki/JSON)
5. The response format is controlled by the header `Accept` (if not specified, then `application/json` will be used).
The following headers are currently supported:
  - `application/json` - [JSON format](https://en.wikipedia.org/wiki/JSON)
  - `application/xml` - [XML format](https://en.wikipedia.org/wiki/XML)

All API requests use the following format: `https://api.servicefusion.com/{version}/{resource}`, where:
- `version` is the version of the API. The current supported version is `v1`.
- `resource` is an API resource. A complete list of all supported resources can be found in the `Resources` tab.

The API has 3 basic operations: 
- Get a list of records.
- Get a single record by ID.
- Create a new record.
  
With each response, the [HTTP status code](https://en.wikipedia.org/wiki/List_of_HTTP_status_codes) corresponding to this response is returned:
- `2xx` successful
- `3xx` redirection
- `4xx` client error
- `5xx` server error

## The answers are `2xx` and `3xx`.
### Getting a list of records (`GET /`)
To get the list of records of the selected resource, you must make a `GET` request to this resource. If successful
the response will return with the [HTTP status code](https://en.wikipedia.org/wiki/List_of_HTTP_status_codes) `200` with approximately the following contents:
```
{
    "items": [
        {
            "id": "1",
            "first_name": "Max",
            "last_name": "Paltsev"
        },
        {
            "id": "2",
            "first_name": "Jerry",
            "last_name": "Wheeler"
        },
        ...
    ],
    "_meta": {
        "totalCount": 200,
        "pageCount": 20,
        "currentPage": 1,
        "perPage": 10
    }
}
```
This answer contains two root elements - `items` contains an array of records of the current resource and `_meta` contains
service information. Also, access to the data of the service information can be obtained through the headers that are returned with each answer.

| Meta | Header | Description |
| ---- | ------ | ----------- |
| `totalCount` | `X-Pagination-Total-Count` | The total number of resources. |
| `pageCount` | `X-Pagination-Page-Count` | The number of pages. |
| `currentPage` | `X-Pagination-Current-Page` | The current page (1-based). |
| `perPage` | `X-Pagination-Per-Page` | The number of resources per page. |

Additionally the GET operation accepts the following parameters:
- `page` : returns the current page of results. If the specified page number is less than the first or last,
the first or last page will be displayed. Example: `?page=2`. By default, this parameter is set to `1`.
- `per-page` : the number of records displayed per page, from `1` to `50`. Example: `?per-page=20`. Default
this parameter is equal to `10`.
- `sort` : sort the displayed records by the specified fields. Example: `?sort=-name,description` sort all records
in the descending order of the field `name` and in the ascending order of the `description` field.
- `filters` : filtering the displayed records according to the specified criteria.
Example: `?filters[name]=John&filters[description]=Walter`.
- `fields` : a list of the displayed fields in the response, separated by a comma. Example: `?fields=name,description`.
Default displays all fields.

### Getting a record by ID (`GET /{id}`)
To obtain a single record from the selected resoure, you must make a `GET` request to this resource with the ID
of the record being requested. If successful, the response returns with the [HTTP status code](https://en.wikipedia.org/wiki/List_of_HTTP_status_codes) `200` with approximately the following
contents:
```
{
    "id": "1",
    "first_name": "Max",
    "last_name": "Paltsev"
}
```
Additionally, the (`GET/{id}`) operation accepts the following paramter:
- `fields` : a list of the displayed fields in the response, separated by a comma.  Example: `?fields=name,description`.

### Creating a new record (`POST /`)
To create a new record for the selected resource, you need to `POST` a request to the resource. If successful
the response will return with the [HTTP status code](https://en.wikipedia.org/wiki/List_of_HTTP_status_codes) `201` with approximately the following contents:
```
{
    "id": "1",
    "first_name": "Max",
    "last_name": "Paltsev"
}
```
Additionally, the (`POST /`) operation accepts the following paramter:
- `fields` : a list of the displayed fields in the response, separated by a comma.  Example: `?fields=name,description`.

## The answers are `4xx` and `5xx`.
### Validation error
If there is an error in the create/update validation, a response will be returned with the [HTTP status code](https://en.wikipedia.org/wiki/List_of_HTTP_status_codes) `422`
with the following content represented by [Error Validation](/v1/#/docs/types-7):
```
[
    {
        "field": "name",
        "message": "Name is too long (maximum is 45 characters)."
    },
    ...
]
```

### Exception
If other errors occur, the response will be returned with the [HTTP status code](https://en.wikipedia.org/wiki/List_of_HTTP_status_codes) `4xx` or` 5xx` 
with the following content represented by [Error Type](/v1/#/docs/types-2):
```
{
    "code": 500,
    "name": "Internal server error.",
    "message": "Failed to create the object for unknown reason."
}
```

### Authentication

# Authentication
## Overview
An Access Token is required to be sent as part of every request to the Service Fusion API, in the
form of an `Authorization: Bearer {{access_token}}` request header or as query parameter
`?access_token={{access_token}}` in the url. Do not use them together.
An Access Token uniquely identifies you for each API request.

## Get an Access Token
Our API uses the [OAuth 2](https://oauth.net/2/) specification and supports 2
of [RFC-6749's](https://tools.ietf.org/html/rfc6749) grant flows.
### Authorization Code Grant ([4.1](https://tools.ietf.org/html/rfc6749#section-4.1))

> This authentication method allows you to get an access token in exchange for the user's usual credentials to log into
the ServiceFusion account, which he will enter in a pop-up window on your site or any other third-party application. This
method consists of 3 steps and is rather complicated to implement, if you need something simpler please look at the
Client Credentials Grant authentication method below.

1. Before you can implement OAuth 2.0 for your app, you need to register your app in
[OAuth Apps](https://admin.servicefusion.com/developerSettings/oauthApps):
  - In [OAuth Apps](https://admin.servicefusion.com/developerSettings/oauthApps), create new app (if you don't already have
  one) by clicking to `Add New OAuth App`.
  - Enter the Name and Redirect URL. When you implement OAuth 2.0 in your app (see next section), the `redirect_uri` must
  match this URL.
  - Click `Add OAuth App`, you will be redirected to the page with the generated Client ID and Client Secret for your app.
  - Save the generated Client ID and Client Secret of your app, you will need them in the next steps.

2. Once you have registered your app, you can implement OAuth 2.0 in your app's code. Your app should start the authorization
flow by directing the user to the Authorization URL:
  ```
    https://api.servicefusion.com/oauth/authorize
      ?response_type=code
      &client_id=YOUR_APP_CLIENT_ID
      &redirect_uri=YOUR_APP_REDIRECT_URL
      &state=YOUR_USER_BOUND_VALUE
  ```
  Where:
  - `response_type`: (required) Set this to `code`.
  - `client_id`: (required) Set this to the app's Client ID generated for your app in
  [OAuth Apps](https://admin.servicefusion.com/developerSettings/oauthApps).
  - `redirect_uri`: (optional) Set this to the Redirect URL configured for your app in
  [OAuth Apps](https://admin.servicefusion.com/developerSettings/oauthApps) (must be identical).
  - `state`: (optional, but recommended for security) Set this to a value that is associated with the user you are directing
  to the authorization URL, for example, a hash of the user's session ID. Make sure that this is a value that cannot be guessed.

3. After the user directed to the Authorization URL successfully passes authentication, he will be redirected back to the
Redirect URL (which you set for your app in [OAuth Apps](https://admin.servicefusion.com/developerSettings/oauthApps)) with
the `code` and `state` (if indicated in the previous step) query parameters. First check that the `state` value matches what
you set it to originally - this serves as a CSRF protection mechanism and you will ensure an attacker can't intercept the
authorization flow. Then exchange the received query parameter `code` for an access token:

> Note: the `code` query parameter lifetime is 60sec and it can be exchanged only once within this 60sec (it is for security
reasons), otherwise an error message that code invalid or expired will be occured.

```
  curl --request POST \
    --url 'https://api.servicefusion.com/oauth/access_token' \
    --header 'content-type: application/json' \
    --data '{"grant_type": "authorization_code", "client_id": "YOUR_APP_CLIENT_ID", "client_secret": "YOUR_APP_CLIENT_SECRET", "code": "QUERY_PARAMETER_CODE", "redirect_uri": "YOUR_APP_REDIRECT_URL"}'
```
Where:
  - `grant_type`: (required) Set this to `authorization_code`.
  - `client_id`: (required) Set this to the app's Client ID generated for your app in
  [OAuth Apps](https://admin.servicefusion.com/developerSettings/oauthApps).
  - `client_secret`: (required) Set this to the app's Client Secret generated for your app in
  [OAuth Apps](https://admin.servicefusion.com/developerSettings/oauthApps).
  - `code`: (required) Set this to the `code` query parameter that the user received when redirecting to the Redirect URL.
  - `redirect_uri`: (optional) Set this to the `redirect_uri` query parameter which was included in the initial authorization
  request (must be identical).

The [response](/v1/#/docs/types-0) contains an Access Token, the token's type (which is `Bearer`), the time (in seconds,
3600 = 1 hour) when the token expires, and a Refresh Token to refresh your Access Token when it expires. If the request
results in an error, it is represented by an [OAuthTokenError](/v1/#/docs/types-1) in the response.
```
  {
    "access_token": "eyJz93a...k4laUWw",
    "token_type": "Bearer",
    "expires_in": 3600,
    "refresh_token": "afGb76r...t8erDVe"
  }
```
### Client Credentials Grant ([4.4](https://tools.ietf.org/html/rfc6749#section-4.4))

> This authentication method allows you to get an access token in exchange for the client's ID and Secret, which he can find
on the page [OAuth Consumer](https://admin.servicefusion.com/developerSettings/oauthConsumer) of his ServiceFusion account.
If you want a more convenient authorization for a user with his usual credentials to enter the ServiceFusion account, please
look at the Authorization Code Grant authentication method above.

To ask for an Access Token for any of your authorized consumers, perform a `POST` operation to
the `https://api.servicefusion.com/oauth/access_token` endpoint with a payload in the following format:
```
  curl --request POST \
    --url 'https://api.servicefusion.com/oauth/access_token' \
    --header 'content-type: application/json' \
    --data '{"grant_type": "client_credentials", "client_id": "YOUR_USER_CLIENT_ID", "client_secret": "YOUR_USER_CLIENT_SECRET"}'
```
Where:
- `grant_type`: (required) Set this to `client_credentials`.
- `client_id`: (required) Set this to the consumer's Client ID generated for your user in
[OAuth Consumer](https://admin.servicefusion.com/developerSettings/oauthConsumer).
- `client_secret`: (required) Set this to the consumer's Client Secret generated for your user in
[OAuth Consumer](https://admin.servicefusion.com/developerSettings/oauthConsumer).

The [response](/v1/#/docs/types-0) contains an Access Token, the token's type (which is `Bearer`), the time (in seconds,
3600 = 1 hour) when the token expires, and a Refresh Token to refresh your Access Token when it expires. If the request
results in an error, it is represented by an [OAuthTokenError](/v1/#/docs/types-1) in the response.
```
  {
    "access_token": "eyJz93a...k4laUWw",
    "token_type": "Bearer",
    "expires_in": 3600,
    "refresh_token": "afGb76r...t8erDVe"
  }
```
## Refresh an Access Token
When the Access Token expires, you can use the Refresh Token to get a new Access Token by using the
token endpoint as shown below:
```
  curl --request POST \
    --url 'https://api.servicefusion.com/oauth/access_token' \
    --header 'content-type: application/json' \
    --data '{"grant_type": "refresh_token", "refresh_token": "afGb76r...t8erDVe"}'
```
Where:
- `grant_type`: (required) Set this to `refresh_token`.
- `refresh_token`: (required) Set this to `refresh_token` value from the Access Token response.

### Rate Limits

# Rate Limits
API access rate limits are applied to each access token at a rate of 60 requests per minute. In addition, every API response is accompanied
by the following set of headers to identify the status of your consumption. 

| Header | Description |
| ------ | ----------- |
| `X-Rate-Limit-Limit` | The maximum number of requests that the consumer is permitted to make per minute. |
| `X-Rate-Limit-Remaining` | The number of requests remaining in the current rate limit window. |
| `X-Rate-Limit-Reset` | The time at which the current rate limit window resets in UTC epoch seconds. |

If too many requests are received from a user within the stated period of the time, a response with status code
`429` (meaning `Too Many Requests`) will be returned.

## Authentication

**Type:** OAuth 2.0

This API supports OAuth 2.0 for authenticating all API requests.

**Headers:**

- `Authorization` (string, optional) — Used to send a valid OAuth 2 access token. Do not use together with the `access_token` query parameter. Example: `Bearer eyJz93a...k4laUWw`

**Response 401:** ### 401 Unauthorized (Client Error)
Authentication is required and has failed or has not yet been provided.
**Response 403:** ### 403 Forbidden (Client Error)
Access to the requested resource is forbidden. The server understood the request, but will not fulfill it.

**OAuth 2.0 Settings:**

- **accessTokenUri:** `https://api.servicefusion.com/oauth/access_token`
- **authorizationGrants:** `authorization_code,client_credentials`

## Endpoint Summary

| Method | Path | Description |
|--------|------|-------------|
| GET | `/v1/me` | Authorized user information. |
| GET | `/v1/calendar-tasks` | List all CalendarTasks matching query criteria, if provided, |
| GET | `/v1/calendar-tasks/{calendar-task-id}` | Get a CalendarTask by identifier. |
| POST | `/v1/customers` | Create a new Customer. |
| GET | `/v1/customers` | List all Customers matching query criteria, if provided, |
| GET | `/v1/customers/{customer-id}` | Get a Customer by identifier. |
| GET | `/v1/customers/{customer-id}/equipment` | List all Equipment matching query criteria, if provided, |
| GET | `/v1/customers/{customer-id}/equipment/{equipment-id}` | Get a Equipment by identifier. |
| POST | `/v1/jobs` | Create a new Job. |
| GET | `/v1/jobs` | List all Jobs matching query criteria, if provided, |
| GET | `/v1/jobs/{job-id}` | Get a Job by identifier. |
| GET | `/v1/job-categories` | List all JobCategories matching query criteria, if provided, |
| GET | `/v1/job-categories/{job-category-id}` | Get a JobCategory by identifier. |
| GET | `/v1/job-statuses` | List all JobStatuses matching query criteria, if provided, |
| GET | `/v1/job-statuses/{job-status-id}` | Get a JobStatus by identifier. |
| POST | `/v1/estimates` | Create a new Estimate. |
| GET | `/v1/estimates` | List all Estimates matching query criteria, if provided, |
| GET | `/v1/estimates/{estimate-id}` | Get a Estimate by identifier. |
| GET | `/v1/invoices` | List all Invoices matching query criteria, if provided, |
| GET | `/v1/invoices/{invoice-id}` | Get a Invoice by identifier. |
| GET | `/v1/payment-types` | List all PaymentTypes matching query criteria, if provided, |
| GET | `/v1/payment-types/{payment-type-id}` | Get a PaymentType by identifier. |
| GET | `/v1/sources` | List all Sources matching query criteria, if provided, |
| GET | `/v1/sources/{source-id}` | Get a Source by identifier. |
| GET | `/v1/techs` | List all Techs matching query criteria, if provided, |
| GET | `/v1/techs/{tech-id}` | Get a Tech by identifier. |

## Endpoints

### /me

### GET `/v1/me`

Authorized user information.

*Traits:* tra.me-fieldable, tra.formatable

**Query Parameters:**

- `fields` (string, optional) (default: `If not passed, will be displayed all available.`) Enum: `id`, `first_name`, `last_name`, `email` — Used to send a list of fields to be displayed. Accepted value is comma-separated string. Example: `id,email`
- `expand` (string, optional) (default: `If not passed, will be displayed nothing.`) — Used to send a list of extra-fields to be displayed. Accepted value is comma-separated string.
- `format` (string, optional) (default: `json`) Enum: `json`, `xml` — Used to send a format of data of the response. Do not use together with the `Accept` header.
- `access_token` (string, optional) — Used to send a valid OAuth 2 access token. Do not use together with the `Authorization` header. Example: `eyJz93a...k4laUWw`

**Response 200:**
### 200 OK (Success) Standard response for successful HTTP requests.
- Type: `object`

- `id` (integer, optional) — The authenticated user's identifier.
- `first_name` (string, optional) — The authenticated user's first name.
- `last_name` (string, optional) — The authenticated user's last name.
- `email` (string, optional) — The authenticated user's email.
- `_expandable` (array, **required**) — The extra-field's list that are not expanded and can be expanded into objects.

Example:
```json
{
  "id": 1472289,
  "first_name": "Justin",
  "last_name": "Wormell",
  "email": "justin@servicefusion.com",
  "_expandable": []
}
```

**Response 400:**
### 400 Bad Request (Client Error) The server cannot or will not process the request due to an apparent client error (e.g., malformed request syntax, size too large, invalid request message framing, or deceptive request routing).
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 400,
  "name": "Bad Request.",
  "message": "Your request is invalid."
}
```

**Response 401:**
### 401 Unauthorized (Client Error) Authentication is required and has failed or has not yet been provided.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 401,
  "name": "Unauthorized.",
  "message": "Your request was made with invalid credentials."
}
```

**Response 403:**
### 403 Forbidden (Client Error) Access to the requested resource is forbidden. The server understood the request, but will not fulfill it.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 403,
  "name": "Forbidden.",
  "message": "Login Required."
}
```

**Response 405:**
### 405 Method Not Allowed (Client Error) A request method is not supported for the requested resource. For example, a GET request on a form that requires data to be presented via POST.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 405,
  "name": "Method not allowed.",
  "message": "Method Not Allowed. This url can only handle the following request methods: GET.\n"
}
```

**Response 415:**
### 415 Unsupported Media Type (Client Error) The request entity has a media type which the server or resource does not support. For example, the client set request data as `application/xml`, but the server requires that request data use a different format.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 415,
  "name": "Unsupported Media Type.",
  "message": "None of your requested content types is supported."
}
```

**Response 429:**
### 429 Too Many Requests (Client Error) The user has sent too many requests in a given amount of time.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 429,
  "name": "Too Many Requests.",
  "message": "Rate limit exceeded."
}
```

**Response 500:**
### 500 Internal Server Error (Server Error) A generic error message, given when an unexpected condition was encountered and no more specific message is suitable.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 500,
  "name": "Internal server error.",
  "message": "Failed to create the object for unknown reason."
}
```

### /calendar-tasks

### GET `/v1/calendar-tasks`

List all CalendarTasks matching query criteria, if provided,
otherwise list all CalendarTasks.

*Traits:* tra.calendarTask-fieldable, tra.calendarTask-sortable, tra.calendarTask-filtrable, tra.formatable

**Query Parameters:**

- `page` (integer, optional) (default: `1`) — Used to send a page number to be displayed. Example: `2`
- `per-page` (integer, optional) (default: `10`) — Used to send a number of items displayed per page (min `1`, max `50`). Example: `20`
- `fields` (string, optional) (default: `If not passed, will be displayed all available.`) Enum: `id`, `type`, `description`, `start_time`, `end_time`, `start_date`, `end_date`, `created_at`, `updated_at`, `is_public`, `is_completed`, `repeat_id`, `users_id`, `customers_id`, `jobs_id`, `estimates_id` — Used to send a list of fields to be displayed. Accepted value is comma-separated string. Example: `id,description,is_completed`
- `expand` (string, optional) (default: `If not passed, will be displayed nothing.`) Enum: `repeat` — Used to send a list of extra-fields to be displayed. Accepted value is comma-separated string. Example: `repeat`
- `sort` (string, optional) (default: `id`) Enum: `id`, `type`, `description`, `start_time`, `end_time`, `start_date`, `end_date`, `created_at`, `updated_at`, `is_public`, `is_completed`, `repeat_id` — Used to sort the results by given fields. Use minus `-` before field name to sort DESC. Accepted value is comma-separated string. Example: `type,-end_time`
- `format` (string, optional) (default: `json`) Enum: `json`, `xml` — Used to send a format of data of the response. Do not use together with the `Accept` header.
- `access_token` (string, optional) — Used to send a valid OAuth 2 access token. Do not use together with the `Authorization` header. Example: `eyJz93a...k4laUWw`

**Response 200:**
### 200 OK (Success) Standard response for successful HTTP requests.
- Type: `object`

- `items` (array, **required**) — Collection envelope.
- `_expandable` (array, **required**) — The extra-field's list that are not expanded and can be expanded into objects.
- `_meta` (object, **required**) — Meta information.
  - `totalCount` (integer, optional) — Total number of data items.
  - `pageCount` (integer, optional) — Total number of pages of data.
  - `currentPage` (integer, optional) — The current page number (1-based).
  - `perPage` (integer, optional) — The number of data items in each page.

Example:
```json
{
  "items": [
    {
      "id": 16546,
      "type": "Call",
      "description": "Zapier task note",
      "start_time": "10:00",
      "end_time": "22:00",
      "start_date": "2021-05-01",
      "end_date": null,
      "created_at": "2021-06-22T11:02:32+00:00",
      "updated_at": "2021-06-22T11:02:32+00:00",
      "is_public": false,
      "is_completed": false,
      "repeat_id": 99,
      "users_id": [
        980190972,
        980190979
      ],
      "customers_id": [
        9303,
        842180
      ],
      "jobs_id": [
        1152721,
        1152722
      ],
      "estimates_id": [
        1152212,
        1152932
      ],
      "repeat": {
        "id": 92,
        "repeat_type": "Daily",
        "repeat_frequency": 2,
        "repeat_weekly_days": [],
        "repeat_monthly_type": null,
        "stop_repeat_type": "On Occurrence",
        "stop_repeat_on_occurrence": 10,
        "stop_repeat_on_date": null,
        "start_date": "2021-05-27T00:00:00+00:00",
        "end_date": "2021-06-14T00:00:00+00:00"
      }
    }
  ],
  "_expandable": [
    "repeat"
  ],
  "_meta": {
    "totalCount": 50,
    "pageCount": 5,
    "currentPage": 1,
    "perPage": 10
  }
}
```

**Response 400:**
### 400 Bad Request (Client Error) The server cannot or will not process the request due to an apparent client error (e.g., malformed request syntax, size too large, invalid request message framing, or deceptive request routing).
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 400,
  "name": "Bad Request.",
  "message": "Your request is invalid."
}
```

**Response 401:**
### 401 Unauthorized (Client Error) Authentication is required and has failed or has not yet been provided.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 401,
  "name": "Unauthorized.",
  "message": "Your request was made with invalid credentials."
}
```

**Response 403:**
### 403 Forbidden (Client Error) Access to the requested resource is forbidden. The server understood the request, but will not fulfill it.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 403,
  "name": "Forbidden.",
  "message": "Login Required."
}
```

**Response 405:**
### 405 Method Not Allowed (Client Error) A request method is not supported for the requested resource. For example, a GET request on a form that requires data to be presented via POST.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 405,
  "name": "Method not allowed.",
  "message": "Method Not Allowed. This url can only handle the following request methods: GET.\n"
}
```

**Response 415:**
### 415 Unsupported Media Type (Client Error) The request entity has a media type which the server or resource does not support. For example, the client set request data as `application/xml`, but the server requires that request data use a different format.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 415,
  "name": "Unsupported Media Type.",
  "message": "None of your requested content types is supported."
}
```

**Response 429:**
### 429 Too Many Requests (Client Error) The user has sent too many requests in a given amount of time.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 429,
  "name": "Too Many Requests.",
  "message": "Rate limit exceeded."
}
```

**Response 500:**
### 500 Internal Server Error (Server Error) A generic error message, given when an unexpected condition was encountered and no more specific message is suitable.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 500,
  "name": "Internal server error.",
  "message": "Failed to create the object for unknown reason."
}
```

### GET `/v1/calendar-tasks/{calendar-task-id}`

Get a CalendarTask by identifier.

*Traits:* tra.calendarTask-fieldable, tra.formatable

**URI Parameters:**

- `calendar-task-id` (integer, **required**) — Used to send an identifier of the CalendarTask to be used.

**Query Parameters:**

- `fields` (string, optional) (default: `If not passed, will be displayed all available.`) Enum: `id`, `type`, `description`, `start_time`, `end_time`, `start_date`, `end_date`, `created_at`, `updated_at`, `is_public`, `is_completed`, `repeat_id`, `users_id`, `customers_id`, `jobs_id`, `estimates_id` — Used to send a list of fields to be displayed. Accepted value is comma-separated string. Example: `id,description,is_completed`
- `expand` (string, optional) (default: `If not passed, will be displayed nothing.`) Enum: `repeat` — Used to send a list of extra-fields to be displayed. Accepted value is comma-separated string. Example: `repeat`
- `format` (string, optional) (default: `json`) Enum: `json`, `xml` — Used to send a format of data of the response. Do not use together with the `Accept` header.
- `access_token` (string, optional) — Used to send a valid OAuth 2 access token. Do not use together with the `Authorization` header. Example: `eyJz93a...k4laUWw`

**Response 200:**
### 200 OK (Success) Standard response for successful HTTP requests.
- Type: `object`

- `id` (integer, optional) — The calendar task's identifier.
- `type` (string, optional) — The calendar task's type.
- `description` (string, optional) — The calendar task's description.
- `start_time` (string, optional) — The calendar task's start time.
- `end_time` (string, optional) — The calendar task's end time.
- `start_date` (datetime, optional) — The calendar task's start date.
- `end_date` (datetime, optional) — The calendar task's end date.
- `created_at` (datetime, optional) — The calendar task's created date.
- `updated_at` (datetime, optional) — The calendar task's updated date.
- `is_public` (boolean, optional) — The calendar task's is public flag.
- `is_completed` (boolean, optional) — The calendar task's is completed flag.
- `repeat_id` (integer, optional) — The calendar task's repeat id.
- `users_id` (array, **required**) — The calendar task's users list of identifiers.
- `customers_id` (array, **required**) — The calendar task's customers list of identifiers.
- `jobs_id` (array, **required**) — The calendar task's jobs list of identifiers.
- `estimates_id` (array, **required**) — The calendar task's estimates list of identifiers.
- `repeat` (object, optional) — The calendar task's repeat. Example: `{
  "id": 92,
  "repeat_type": "Daily",
  "repeat_frequency": 2,
  "repeat_weekly_days": [],
  "repeat_monthly_type": null,
  "stop_repeat_type": "On Occurrence",
  "stop_repeat_on_occurrence": 10,
  "stop_repeat_on_date": null,
  "start_date": "2021-05-27T00:00:00+00:00",
  "end_date": "2021-06-14T00:00:00+00:00"
}`
  - `id` (integer, optional) — The repeat's identifier.
  - `repeat_type` (string, optional) — The repeat's type.
  - `repeat_frequency` (integer, optional) — The repeat's frequency.
  - `repeat_weekly_days` (array, **required**) — The repeat's weekly days list.
  - `repeat_monthly_type` (string, optional) — The repeat's monthly type.
  - `stop_repeat_type` (string, optional) — The repeat's stop type.
  - `stop_repeat_on_occurrence` (integer, optional) — The repeat's stop on occurrence.
  - `stop_repeat_on_date` (datetime, optional) — The repeat's stop on date.
  - `start_date` (datetime, optional) — The repeat's start date.
  - `end_date` (datetime, optional) — The repeat's end date.
- `_expandable` (array, **required**) — The extra-field's list that are not expanded and can be expanded into objects.

Example:
```json
{
  "id": 16546,
  "type": "Call",
  "description": "Zapier task note",
  "start_time": "10:00",
  "end_time": "22:00",
  "start_date": "2021-05-01",
  "end_date": null,
  "created_at": "2021-06-22T11:02:32+00:00",
  "updated_at": "2021-06-22T11:02:32+00:00",
  "is_public": false,
  "is_completed": false,
  "repeat_id": 99,
  "users_id": [
    980190972,
    980190979
  ],
  "customers_id": [
    9303,
    842180
  ],
  "jobs_id": [
    1152721,
    1152722
  ],
  "estimates_id": [
    1152212,
    1152932
  ],
  "repeat": {
    "id": 92,
    "repeat_type": "Daily",
    "repeat_frequency": 2,
    "repeat_weekly_days": [],
    "repeat_monthly_type": null,
    "stop_repeat_type": "On Occurrence",
    "stop_repeat_on_occurrence": 10,
    "stop_repeat_on_date": null,
    "start_date": "2021-05-27T00:00:00+00:00",
    "end_date": "2021-06-14T00:00:00+00:00"
  },
  "_expandable": [
    "repeat"
  ]
}
```

**Response 400:**
### 400 Bad Request (Client Error) The server cannot or will not process the request due to an apparent client error (e.g., malformed request syntax, size too large, invalid request message framing, or deceptive request routing).
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 400,
  "name": "Bad Request.",
  "message": "Your request is invalid."
}
```

**Response 401:**
### 401 Unauthorized (Client Error) Authentication is required and has failed or has not yet been provided.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 401,
  "name": "Unauthorized.",
  "message": "Your request was made with invalid credentials."
}
```

**Response 403:**
### 403 Forbidden (Client Error) Access to the requested resource is forbidden. The server understood the request, but will not fulfill it.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 403,
  "name": "Forbidden.",
  "message": "Login Required."
}
```

**Response 404:**
### 404 Not Found (Client Error) The requested resource could not be found but may be available in the future.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 404,
  "name": "Not Found.",
  "message": "Item not found."
}
```

**Response 405:**
### 405 Method Not Allowed (Client Error) A request method is not supported for the requested resource. For example, a GET request on a form that requires data to be presented via POST.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 405,
  "name": "Method not allowed.",
  "message": "Method Not Allowed. This url can only handle the following request methods: GET.\n"
}
```

**Response 415:**
### 415 Unsupported Media Type (Client Error) The request entity has a media type which the server or resource does not support. For example, the client set request data as `application/xml`, but the server requires that request data use a different format.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 415,
  "name": "Unsupported Media Type.",
  "message": "None of your requested content types is supported."
}
```

**Response 429:**
### 429 Too Many Requests (Client Error) The user has sent too many requests in a given amount of time.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 429,
  "name": "Too Many Requests.",
  "message": "Rate limit exceeded."
}
```

**Response 500:**
### 500 Internal Server Error (Server Error) A generic error message, given when an unexpected condition was encountered and no more specific message is suitable.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 500,
  "name": "Internal server error.",
  "message": "Failed to create the object for unknown reason."
}
```

### /customers

### POST `/v1/customers`

Create a new Customer.

*Traits:* tra.customer-fieldable, tra.formatable

**Query Parameters:**

- `fields` (string, optional) (default: `If not passed, will be displayed all available.`) Enum: `id`, `customer_name`, `fully_qualified_name`, `account_number`, `account_balance`, `private_notes`, `public_notes`, `payment_terms`, `discount`, `discount_type`, `credit_rating`, `labor_charge_type`, `labor_charge_default_rate`, `qbo_sync_token`, `qbo_currency`, `qbo_id`, `qbd_id`, `created_at`, `updated_at`, `last_serviced_date`, `is_bill_for_drive_time`, `is_vip`, `is_taxable`, `parent_customer`, `referral_source`, `agent`, `assigned_contract`, `payment_type`, `tax_item_name`, `industry` — Used to send a list of fields to be displayed. Accepted value is comma-separated string. Example: `id,customer_name,discount`
- `expand` (string, optional) (default: `If not passed, will be displayed nothing.`) Enum: `contacts`, `contacts.phones`, `contacts.emails`, `locations`, `custom_fields` — Used to send a list of extra-fields to be displayed. Accepted value is comma-separated string. Example: `contacts.phones,locations`
- `format` (string, optional) (default: `json`) Enum: `json`, `xml` — Used to send a format of data of the response. Do not use together with the `Accept` header.
- `access_token` (string, optional) — Used to send a valid OAuth 2 access token. Do not use together with the `Authorization` header. Example: `eyJz93a...k4laUWw`

**Request Body** (`0`):
- Type: `object`

- `customer_name` (string, **required**) — Used to send the customer's name that will be set.
- `parent_customer` (string, optional) — Used to send a parent customer's `id` or `header` that will be attached to the customer (Note: `id` - [integer] the parent customer's identifier, `header` - [string] the parent customer's fields concatenated by pattern `{customer_name}`).
- `account_number` (string, optional) (default: `If not passed, it takes generated new one.`) — Used to send the customer's account number that will be set.
- `private_notes` (string, optional) — Used to send the customer's private notes that will be set.
- `public_notes` (string, optional) — Used to send the customer's public notes that will be set.
- `credit_rating` (string, optional) (default: `If not passed, it takes the value from parent customer (configurable into the company preferences).`) Enum: `A+`, `A`, `B+`, `B`, `C+`, `C`, `U` — Used to send the customer's credit rating that will be set.
- `labor_charge_type` (string, optional) (default: `If not passed, it takes the value from parent customer (configurable into the company preferences).`) Enum: `flat`, `hourly` — Used to send the customer's labor charge type that will be set.
- `labor_charge_default_rate` (number, optional) (default: `If not passed, it takes the value from parent customer (configurable into the company preferences).`) — Used to send the customer's labor charge default rate that will be set.
- `last_serviced_date` (datetime, optional) — Used to send the customer's last serviced date that will be set.
- `is_bill_for_drive_time` (boolean, optional) (default: `If not passed, it takes the value from parent customer (configurable into the company preferences).`) — Used to send the customer's is bill for drive time flag that will be set.
- `is_vip` (boolean, optional) — Used to send the customer's is vip flag that will be set.
- `referral_source` (string, optional) — Used to send a referral source's `id` or `header` that will be attached to the customer (Note: `id` - [integer] the referral source's identifier, `header` - [string] the referral source's fields concatenated by pattern `{short_name}`).
- `agent` (string, optional) — Used to send an agent's `id` or `header` that will be attached to the customer (Note: `id` - [integer] the agent's identifier, `header` - [string] the agent's fields concatenated by pattern `{first_name} {last_name}` with space as separator).
- `discount` (number, optional) (default: `If not passed, it takes the value from parent customer (configurable into the company preferences).`) — Used to send the customer's discount that will be set.
- `discount_type` (string, optional) (default: `If not passed, it takes the value from parent customer (configurable into the company preferences).`) Enum: `$`, `%` — Used to send the customer's discount type that will be set.
- `payment_type` (string, optional) (default: `If not passed, it takes the value from the company preferences or from parent customer (configurable into the company preferences).`) — Used to send a payment type's `id` or `header` that will be attached to the customer (Note: `id` - [integer] the payment type's identifier, `header` - [string] the payment type's fields concatenated by pattern `{name}`).
- `payment_terms` (string, optional) (default: `If not passed, it takes the value from the company preferences or from parent customer (configurable into the company preferences).`) — Used to send the customer's payment terms that will be set.
- `assigned_contract` (string, optional) — Used to send an assigned contract's `id` or `header` that will be attached to the customer (Note: `id` - [integer] the assigned contract's identifier, `header` - [string] the assigned contract's fields concatenated by pattern `{contract_title}`).
- `industry` (string, optional) — Used to send an industry's `id` or `header` that will be attached to the customer (Note: `id` - [integer] the industry's identifier, `header` - [string] the industry's fields concatenated by pattern `{industry}`).
- `is_taxable` (boolean, optional) (default: `If not passed, it takes the value `true` (configurable into the company preferences).`) — Used to send the customer's is taxable flag that will be set.
- `tax_item_name` (string, optional) (default: `If not passed, it takes the value from the company preferences (configurable into the company preferences).`) — Used to send a tax item's `id` or `header` that will be attached to the customer (Note: `id` - [integer] the tax item's identifier, `header` - [string] the tax item's fields concatenated by pattern `{short_name}`).
- `qbo_sync_token` (integer, optional) — Used to send the customer's qbo sync token that will be set.
- `qbo_currency` (string, optional) (default: `If not passed, it takes the value from the company if it was configured, otherwise it takes the value `USD`.`) Enum: `USD`, `CAD`, `JMD`, `THB` — Used to send the customer's qbo currency that will be set.
- `contacts` (array, optional) (default: `If not passed, it creates the new one.`) — Used to send the customer's contacts list that will be set.
- `locations` (array, optional) (default: `array`) — Used to send the customer's locations list that will be set.
- `custom_fields` (array, optional) (default: `If some custom field (configured into the custom fields settings) not passed, it creates the new one with its default value.`) — Used to send the customer's custom fields list that will be set.

Example:
```json
{
  "customer_name": "Bob Marley",
  "parent_customer": "Jerry Wheeler",
  "account_number": "30000",
  "private_notes": "None",
  "public_notes": "None",
  "credit_rating": "A+",
  "labor_charge_type": "flat",
  "labor_charge_default_rate": 50.45,
  "last_serviced_date": "2018-08-07",
  "is_bill_for_drive_time": true,
  "is_vip": true,
  "referral_source": "Google AdWords",
  "agent": "John Theowner",
  "discount": 10.23,
  "discount_type": "%",
  "payment_type": "Check",
  "payment_terms": "DUR",
  "assigned_contract": "Retail Service Contract",
  "industry": "Advertising Agencies",
  "is_taxable": false,
  "tax_item_name": "Sanity Tax",
  "qbo_sync_token": 385,
  "qbo_currency": "USD",
  "contacts": [
    {
      "prefix": "Mr.",
      "fname": "Jerry",
      "lname": "Wheeler",
      "suffix": "suf",
      "contact_type": "Billing",
      "dob": "April 19",
      "anniversary": "October 4",
      "job_title": "Manager",
      "department": "executive",
      "is_primary": true,
      "phones": [
        {
          "phone": "066-361-8172",
          "ext": 38,
          "type": "Mobile"
        }
      ],
      "emails": [
        {
          "email": "anton.lyubch1@gmail.com",
          "class": "Personal",
          "types_accepted": "CONF,PMT"
        }
      ]
    }
  ],
  "locations": [
    {
      "street_1": "1904 Industrial Blvd",
      "street_2": "103",
      "city": "Colleyville",
      "state_prov": "Texas",
      "postal_code": "76034",
      "country": "USA",
      "nickname": "Office",
      "gate_instructions": "Gate instructions",
      "latitude": "123.45",
      "longitude": "67.89",
      "location_type": "home",
      "is_primary": false,
      "is_gated": false,
      "is_bill_to": false,
      "customer_contact": "Sam Smith"
    }
  ],
  "custom_fields": [
    {
      "name": "Text",
      "value": "Example text value"
    },
    {
      "name": "Textarea",
      "value": "Example text area value"
    },
    {
      "name": "Date",
      "value": "2018-10-05"
    },
    {
      "name": "Numeric",
      "value": "157.25"
    },
    {
      "name": "Select",
      "value": "1 one"
    },
    {
      "name": "Checkbox",
      "value": true
    }
  ]
}
```

**Response 201:**
### 201 Created (Success) The request has been fulfilled, resulting in the creation of a new resource.
- Type: `object`

- `id` (integer, optional) — The customer's identifier.
- `customer_name` (string, optional) — The customer's name.
- `fully_qualified_name` (string, optional) — The customer's fully qualified name.
- `parent_customer` (string, optional) — The `header` of attached parent customer to the customer (Note: `header` - [string] the parent customer's fields concatenated by pattern `{first_name} {last_name}` with space as separator).
- `account_number` (string, optional) — The customer's account number.
- `account_balance` (number, optional) — The customer's account balance.
- `private_notes` (string, optional) — The customer's private notes.
- `public_notes` (string, optional) — The customer's public notes.
- `credit_rating` (string, optional) — The customer's credit rating.
- `labor_charge_type` (string, optional) — The customer's labor charge type.
- `labor_charge_default_rate` (number, optional) — The customer's labor charge default rate.
- `last_serviced_date` (datetime, optional) — The customer's last serviced date.
- `is_bill_for_drive_time` (boolean, optional) — The customer's is bill for drive time flag.
- `is_vip` (boolean, optional) — The customer's is vip flag.
- `referral_source` (string, optional) — The `header` of attached referral source to the customer (Note: `header` - [string] the referral source's fields concatenated by pattern `{short_name}`).
- `agent` (string, optional) — The `header` of attached agent to the customer (Note: `header` - [string] the agent's fields concatenated by pattern `{first_name} {last_name}` with space as separator).
- `discount` (number, optional) — The customer's discount.
- `discount_type` (string, optional) — The customer's discount type.
- `payment_type` (string, optional) — The `header` of attached payment type to the customer (Note: `header` - [string] the payment type's fields concatenated by pattern `{name}`).
- `payment_terms` (string, optional) — The customer's payment terms.
- `assigned_contract` (string, optional) — The `header` of attached contract to the customer (Note: `header` - [string] the contract's fields concatenated by pattern `{contract_title}`).
- `industry` (string, optional) — The `header` of attached industry to the customer (Note: `header` - [string] the industry's fields concatenated by pattern `{industry}`).
- `is_taxable` (boolean, optional) — The customer's is taxable flag.
- `tax_item_name` (string, optional) — The `header` of attached tax item to the customer (Note: `header` - [string] the tax item's fields concatenated by pattern `{short_name}` with space as separator).
- `qbo_sync_token` (integer, optional) — The customer's qbo sync token.
- `qbo_currency` (string, optional) — The customer's qbo currency.
- `qbo_id` (integer, optional) — The customer's qbo id.
- `qbd_id` (string, optional) — The customer's qbd id.
- `created_at` (datetime, optional) — The customer's created date.
- `updated_at` (datetime, optional) — The customer's updated date.
- `contacts` (array, optional) — The customer's contacts list.
- `locations` (array, optional) — The customer's locations list.
- `custom_fields` (array, optional) — The customer's custom fields list.
- `_expandable` (array, **required**) — The extra-field's list that are not expanded and can be expanded into objects.

Example:
```json
{
  "id": 1472289,
  "customer_name": "Bob Marley",
  "fully_qualified_name": "Bob Marley",
  "parent_customer": "Jerry Wheeler",
  "account_number": "30000",
  "account_balance": 10.34,
  "private_notes": "None",
  "public_notes": "None",
  "credit_rating": "A+",
  "labor_charge_type": "flat",
  "labor_charge_default_rate": 50.45,
  "last_serviced_date": "2018-08-07",
  "is_bill_for_drive_time": true,
  "is_vip": true,
  "referral_source": "Google AdWords",
  "agent": "John Theowner",
  "discount": 10.23,
  "discount_type": "%",
  "payment_type": "Check",
  "payment_terms": "DUR",
  "assigned_contract": "Retail Service Contract",
  "industry": "Advertising Agencies",
  "is_taxable": false,
  "tax_item_name": "Sanity Tax",
  "qbo_sync_token": 385,
  "qbo_currency": "USD",
  "qbo_id": null,
  "qbd_id": null,
  "created_at": "2018-08-07T18:31:28+00:00",
  "updated_at": "2018-08-07T18:31:28+00:00",
  "contacts": [
    {
      "prefix": "Mr.",
      "fname": "Jerry",
      "lname": "Wheeler",
      "suffix": "suf",
      "contact_type": "Billing",
      "dob": "April 19",
      "anniversary": "October 4",
      "job_title": "Manager",
      "department": "executive",
      "created_at": "2016-12-21T14:12:08+00:00",
      "updated_at": "2016-12-21T14:12:08+00:00",
      "is_primary": true,
      "phones": [
        {
          "phone": "066-361-8172",
          "ext": 38,
          "type": "Mobile",
          "created_at": "2018-10-05T11:51:48+00:00",
          "updated_at": "2018-10-05T11:54:09+00:00",
          "is_mobile": true
        }
      ],
      "emails": [
        {
          "email": "anton.lyubch1@gmail.com",
          "class": "Personal",
          "types_accepted": "CONF,PMT",
          "created_at": "2018-10-05T11:51:48+00:00",
          "updated_at": "2018-10-05T11:54:09+00:00"
        }
      ]
    }
  ],
  "locations": [
    {
      "street_1": "1904 Industrial Blvd",
      "street_2": "103",
      "city": "Colleyville",
      "state_prov": "Texas",
      "postal_code": "76034",
      "country": "USA",
      "nickname": "Office",
      "gate_instructions": "Gate instructions",
      "latitude": 123.45,
      "longitude": 67.89,
      "location_type": "home",
      "created_at": "2018-08-07T18:31:28+00:00",
      "updated_at": "2018-08-07T18:31:28+00:00",
      "is_primary": false,
      "is_gated": false,
      "is_bill_to": false,
      "customer_contact": "Sam Smith"
    }
  ],
  "custom_fields": [
    {
      "name": "Text",
      "value": "Example text value",
      "type": "text",
      "group": "Default",
      "created_at": "2018-10-11T11:52:33+00:00",
      "updated_at": "2018-10-11T11:52:33+00:00",
      "is_required": true
    }
  ],
  "_expandable": [
    "contacts",
    "contacts.phones",
    "contacts.emails",
    "locations",
    "custom_fields"
  ]
}
```

**Response 400:**
### 400 Bad Request (Client Error) The server cannot or will not process the request due to an apparent client error (e.g., malformed request syntax, size too large, invalid request message framing, or deceptive request routing).
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 400,
  "name": "Bad Request.",
  "message": "Your request is invalid."
}
```

**Response 401:**
### 401 Unauthorized (Client Error) Authentication is required and has failed or has not yet been provided.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 401,
  "name": "Unauthorized.",
  "message": "Your request was made with invalid credentials."
}
```

**Response 403:**
### 403 Forbidden (Client Error) Access to the requested resource is forbidden. The server understood the request, but will not fulfill it.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 403,
  "name": "Forbidden.",
  "message": "Login Required."
}
```

**Response 405:**
### 405 Method Not Allowed (Client Error) A request method is not supported for the requested resource. For example, a GET request on a form that requires data to be presented via POST.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 405,
  "name": "Method not allowed.",
  "message": "Method Not Allowed. This url can only handle the following request methods: GET.\n"
}
```

**Response 415:**
### 415 Unsupported Media Type (Client Error) The request entity has a media type which the server or resource does not support. For example, the client set request data as `application/xml`, but the server requires that request data use a different format.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 415,
  "name": "Unsupported Media Type.",
  "message": "None of your requested content types is supported."
}
```

**Response 422:**
### 422 Unprocessable Entity (Client Error) The request was well-formed but was unable to be followed due to semantic errors.
- Type: `array`

Example:
```json
[
  {
    "field": "name",
    "message": "Name is too long (maximum is 45 characters)."
  }
]
```

**Response 429:**
### 429 Too Many Requests (Client Error) The user has sent too many requests in a given amount of time.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 429,
  "name": "Too Many Requests.",
  "message": "Rate limit exceeded."
}
```

**Response 500:**
### 500 Internal Server Error (Server Error) A generic error message, given when an unexpected condition was encountered and no more specific message is suitable.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 500,
  "name": "Internal server error.",
  "message": "Failed to create the object for unknown reason."
}
```

### GET `/v1/customers`

List all Customers matching query criteria, if provided,
otherwise list all Customers.

*Traits:* tra.customer-fieldable, tra.customer-sortable, tra.customer-filtrable, tra.formatable

**Query Parameters:**

- `page` (integer, optional) (default: `1`) — Used to send a page number to be displayed. Example: `2`
- `per-page` (integer, optional) (default: `10`) — Used to send a number of items displayed per page (min `1`, max `50`). Example: `20`
- `fields` (string, optional) (default: `If not passed, will be displayed all available.`) Enum: `id`, `customer_name`, `fully_qualified_name`, `account_number`, `account_balance`, `private_notes`, `public_notes`, `payment_terms`, `discount`, `discount_type`, `credit_rating`, `labor_charge_type`, `labor_charge_default_rate`, `qbo_sync_token`, `qbo_currency`, `qbo_id`, `qbd_id`, `created_at`, `updated_at`, `last_serviced_date`, `is_bill_for_drive_time`, `is_vip`, `is_taxable`, `parent_customer`, `referral_source`, `agent`, `assigned_contract`, `payment_type`, `tax_item_name`, `industry` — Used to send a list of fields to be displayed. Accepted value is comma-separated string. Example: `id,customer_name,discount`
- `expand` (string, optional) (default: `If not passed, will be displayed nothing.`) Enum: `contacts`, `contacts.phones`, `contacts.emails`, `locations`, `custom_fields` — Used to send a list of extra-fields to be displayed. Accepted value is comma-separated string. Example: `contacts.phones,locations`
- `sort` (string, optional) (default: `id`) Enum: `id`, `customer_name`, `fully_qualified_name`, `account_number`, `private_notes`, `public_notes`, `payment_terms`, `discount`, `discount_type`, `credit_rating`, `labor_charge_type`, `labor_charge_default_rate`, `qbo_sync_token`, `qbo_currency`, `qbo_id`, `qbd_id`, `created_at`, `updated_at`, `last_serviced_date`, `is_bill_for_drive_time`, `is_vip`, `is_taxable`, `parent_customer`, `referral_source`, `agent`, `assigned_contract`, `payment_type`, `tax_item_name`, `industry` — Used to sort the results by given fields. Use minus `-` before field name to sort DESC. Accepted value is comma-separated string. Example: `-customer_name,created_at`
- `filters[name]` (string, optional) — Used to filter results by given name (partial match). Example: `John`
- `filters[contact_first_name]` (string, optional) — Used to filter results by given contact's first name (partial match). Example: `John`
- `filters[contact_last_name]` (string, optional) — Used to filter results by given contact's last name (partial match). Example: `Walter`
- `filters[address]` (string, optional) — Used to filter results by given address (partial match). Example: `3210 Midway Ave`
- `filters[city]` (string, optional) — Used to filter results by given city (full match). Example: `Dallas`
- `filters[postal_code]` (integer, optional) — Used to filter results by given postal code (full match). Example: `75242`
- `filters[phone]` (string, optional) — Used to filter results by given phone (partial match). Example: `214-555-1212`
- `filters[email]` (string, optional) — Used to filter results by given email (full match). Example: `john.walter@gmail.com`
- `filters[tags]` (string, optional) — Used to filter results by given tags (full match). Accepted value is comma-separated string. Example: `Problem Customer, User`
- `filters[last_serviced_date][lte]` (string, optional) — Used to filter results by given `less than or equal` of last serviced date (format: `Y-m-d`). Example: `2002-10-02`
- `filters[last_serviced_date][gte]` (string, optional) — Used to filter results by given `greater than or equal` of last serviced date (format: `Y-m-d`). Example: `2002-10-02`
- `filters[agreement_date_effective][lte]` (string, optional) — Used to filter results by given `less than or equal` of agreement date effective (format `RFC 3339`: `Y-m-d\TH:i:sP`). Example: `2002-10-02T10:00:00-05:00`
- `filters[agreement_date_effective][gte]` (string, optional) — Used to filter results by given `greater than or equal` of agreement date effective (format `RFC 3339`: `Y-m-d\TH:i:sP`). Example: `2002-10-02T10:00:00-05:00`
- `filters[agreement_date_expires][lte]` (string, optional) — Used to filter results by given `less than or equal` of agreement date expires (format `RFC 3339`: `Y-m-d\TH:i:sP`). Example: `2002-10-02T10:00:00-05:00`
- `filters[agreement_date_expires][gte]` (string, optional) — Used to filter results by given `greater than or equal` of agreement date expires (format `RFC 3339`: `Y-m-d\TH:i:sP`). Example: `2002-10-02T10:00:00-05:00`
- `format` (string, optional) (default: `json`) Enum: `json`, `xml` — Used to send a format of data of the response. Do not use together with the `Accept` header.
- `access_token` (string, optional) — Used to send a valid OAuth 2 access token. Do not use together with the `Authorization` header. Example: `eyJz93a...k4laUWw`

**Response 200:**
### 200 OK (Success) Standard response for successful HTTP requests.
- Type: `object`

- `items` (array, **required**) — Collection envelope.
- `_expandable` (array, **required**) — The extra-field's list that are not expanded and can be expanded into objects.
- `_meta` (object, **required**) — Meta information.
  - `totalCount` (integer, optional) — Total number of data items.
  - `pageCount` (integer, optional) — Total number of pages of data.
  - `currentPage` (integer, optional) — The current page number (1-based).
  - `perPage` (integer, optional) — The number of data items in each page.

Example:
```json
{
  "items": [
    {
      "id": 1472289,
      "customer_name": "Bob Marley",
      "fully_qualified_name": "Bob Marley",
      "parent_customer": "Jerry Wheeler",
      "account_number": "30000",
      "account_balance": 10.34,
      "private_notes": "None",
      "public_notes": "None",
      "credit_rating": "A+",
      "labor_charge_type": "flat",
      "labor_charge_default_rate": 50.45,
      "last_serviced_date": "2018-08-07",
      "is_bill_for_drive_time": true,
      "is_vip": true,
      "referral_source": "Google AdWords",
      "agent": "John Theowner",
      "discount": 10.23,
      "discount_type": "%",
      "payment_type": "Check",
      "payment_terms": "DUR",
      "assigned_contract": "Retail Service Contract",
      "industry": "Advertising Agencies",
      "is_taxable": false,
      "tax_item_name": "Sanity Tax",
      "qbo_sync_token": 385,
      "qbo_currency": "USD",
      "qbo_id": null,
      "qbd_id": null,
      "created_at": "2018-08-07T18:31:28+00:00",
      "updated_at": "2018-08-07T18:31:28+00:00",
      "contacts": [
        {
          "prefix": "Mr.",
          "fname": "Jerry",
          "lname": "Wheeler",
          "suffix": "suf",
          "contact_type": "Billing",
          "dob": "April 19",
          "anniversary": "October 4",
          "job_title": "Manager",
          "department": "executive",
          "created_at": "2016-12-21T14:12:08+00:00",
          "updated_at": "2016-12-21T14:12:08+00:00",
          "is_primary": true,
          "phones": [
            {
              "phone": "066-361-8172",
              "ext": 38,
              "type": "Mobile",
              "created_at": "2018-10-05T11:51:48+00:00",
              "updated_at": "2018-10-05T11:54:09+00:00",
              "is_mobile": true
            }
          ],
          "emails": [
            {
              "email": "anton.lyubch1@gmail.com",
              "class": "Personal",
              "types_accepted": "CONF,PMT",
              "created_at": "2018-10-05T11:51:48+00:00",
              "updated_at": "2018-10-05T11:54:09+00:00"
            }
          ]
        }
      ],
      "locations": [
        {
          "street_1": "1904 Industrial Blvd",
          "street_2": "103",
          "city": "Colleyville",
          "state_prov": "Texas",
          "postal_code": "76034",
          "country": "USA",
          "nickname": "Office",
          "gate_instructions": "Gate instructions",
          "latitude": 123.45,
          "longitude": 67.89,
          "location_type": "home",
          "created_at": "2018-08-07T18:31:28+00:00",
          "updated_at": "2018-08-07T18:31:28+00:00",
          "is_primary": false,
          "is_gated": false,
          "is_bill_to": false,
          "customer_contact": "Sam Smith"
        }
      ],
      "custom_fields": [
        {
          "name": "Text",
          "value": "Example text value",
          "type": "text",
          "group": "Default",
          "created_at": "2018-10-11T11:52:33+00:00",
          "updated_at": "2018-10-11T11:52:33+00:00",
          "is_required": true
        }
      ]
    }
  ],
  "_expandable": [
    "contacts",
    "contacts.phones",
    "contacts.emails",
    "locations",
    "custom_fields"
  ],
  "_meta": {
    "totalCount": 50,
    "pageCount": 5,
    "currentPage": 1,
    "perPage": 10
  }
}
```

**Response 400:**
### 400 Bad Request (Client Error) The server cannot or will not process the request due to an apparent client error (e.g., malformed request syntax, size too large, invalid request message framing, or deceptive request routing).
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 400,
  "name": "Bad Request.",
  "message": "Your request is invalid."
}
```

**Response 401:**
### 401 Unauthorized (Client Error) Authentication is required and has failed or has not yet been provided.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 401,
  "name": "Unauthorized.",
  "message": "Your request was made with invalid credentials."
}
```

**Response 403:**
### 403 Forbidden (Client Error) Access to the requested resource is forbidden. The server understood the request, but will not fulfill it.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 403,
  "name": "Forbidden.",
  "message": "Login Required."
}
```

**Response 405:**
### 405 Method Not Allowed (Client Error) A request method is not supported for the requested resource. For example, a GET request on a form that requires data to be presented via POST.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 405,
  "name": "Method not allowed.",
  "message": "Method Not Allowed. This url can only handle the following request methods: GET.\n"
}
```

**Response 415:**
### 415 Unsupported Media Type (Client Error) The request entity has a media type which the server or resource does not support. For example, the client set request data as `application/xml`, but the server requires that request data use a different format.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 415,
  "name": "Unsupported Media Type.",
  "message": "None of your requested content types is supported."
}
```

**Response 429:**
### 429 Too Many Requests (Client Error) The user has sent too many requests in a given amount of time.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 429,
  "name": "Too Many Requests.",
  "message": "Rate limit exceeded."
}
```

**Response 500:**
### 500 Internal Server Error (Server Error) A generic error message, given when an unexpected condition was encountered and no more specific message is suitable.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 500,
  "name": "Internal server error.",
  "message": "Failed to create the object for unknown reason."
}
```

### GET `/v1/customers/{customer-id}`

Get a Customer by identifier.

*Traits:* tra.customer-fieldable, tra.formatable

**URI Parameters:**

- `customer-id` (integer, **required**) — Used to send an identifier of the Customer to be used.

**Query Parameters:**

- `fields` (string, optional) (default: `If not passed, will be displayed all available.`) Enum: `id`, `customer_name`, `fully_qualified_name`, `account_number`, `account_balance`, `private_notes`, `public_notes`, `payment_terms`, `discount`, `discount_type`, `credit_rating`, `labor_charge_type`, `labor_charge_default_rate`, `qbo_sync_token`, `qbo_currency`, `qbo_id`, `qbd_id`, `created_at`, `updated_at`, `last_serviced_date`, `is_bill_for_drive_time`, `is_vip`, `is_taxable`, `parent_customer`, `referral_source`, `agent`, `assigned_contract`, `payment_type`, `tax_item_name`, `industry` — Used to send a list of fields to be displayed. Accepted value is comma-separated string. Example: `id,customer_name,discount`
- `expand` (string, optional) (default: `If not passed, will be displayed nothing.`) Enum: `contacts`, `contacts.phones`, `contacts.emails`, `locations`, `custom_fields` — Used to send a list of extra-fields to be displayed. Accepted value is comma-separated string. Example: `contacts.phones,locations`
- `format` (string, optional) (default: `json`) Enum: `json`, `xml` — Used to send a format of data of the response. Do not use together with the `Accept` header.
- `access_token` (string, optional) — Used to send a valid OAuth 2 access token. Do not use together with the `Authorization` header. Example: `eyJz93a...k4laUWw`

**Response 200:**
### 200 OK (Success) Standard response for successful HTTP requests.
- Type: `object`

- `id` (integer, optional) — The customer's identifier.
- `customer_name` (string, optional) — The customer's name.
- `fully_qualified_name` (string, optional) — The customer's fully qualified name.
- `parent_customer` (string, optional) — The `header` of attached parent customer to the customer (Note: `header` - [string] the parent customer's fields concatenated by pattern `{first_name} {last_name}` with space as separator).
- `account_number` (string, optional) — The customer's account number.
- `account_balance` (number, optional) — The customer's account balance.
- `private_notes` (string, optional) — The customer's private notes.
- `public_notes` (string, optional) — The customer's public notes.
- `credit_rating` (string, optional) — The customer's credit rating.
- `labor_charge_type` (string, optional) — The customer's labor charge type.
- `labor_charge_default_rate` (number, optional) — The customer's labor charge default rate.
- `last_serviced_date` (datetime, optional) — The customer's last serviced date.
- `is_bill_for_drive_time` (boolean, optional) — The customer's is bill for drive time flag.
- `is_vip` (boolean, optional) — The customer's is vip flag.
- `referral_source` (string, optional) — The `header` of attached referral source to the customer (Note: `header` - [string] the referral source's fields concatenated by pattern `{short_name}`).
- `agent` (string, optional) — The `header` of attached agent to the customer (Note: `header` - [string] the agent's fields concatenated by pattern `{first_name} {last_name}` with space as separator).
- `discount` (number, optional) — The customer's discount.
- `discount_type` (string, optional) — The customer's discount type.
- `payment_type` (string, optional) — The `header` of attached payment type to the customer (Note: `header` - [string] the payment type's fields concatenated by pattern `{name}`).
- `payment_terms` (string, optional) — The customer's payment terms.
- `assigned_contract` (string, optional) — The `header` of attached contract to the customer (Note: `header` - [string] the contract's fields concatenated by pattern `{contract_title}`).
- `industry` (string, optional) — The `header` of attached industry to the customer (Note: `header` - [string] the industry's fields concatenated by pattern `{industry}`).
- `is_taxable` (boolean, optional) — The customer's is taxable flag.
- `tax_item_name` (string, optional) — The `header` of attached tax item to the customer (Note: `header` - [string] the tax item's fields concatenated by pattern `{short_name}` with space as separator).
- `qbo_sync_token` (integer, optional) — The customer's qbo sync token.
- `qbo_currency` (string, optional) — The customer's qbo currency.
- `qbo_id` (integer, optional) — The customer's qbo id.
- `qbd_id` (string, optional) — The customer's qbd id.
- `created_at` (datetime, optional) — The customer's created date.
- `updated_at` (datetime, optional) — The customer's updated date.
- `contacts` (array, optional) — The customer's contacts list.
- `locations` (array, optional) — The customer's locations list.
- `custom_fields` (array, optional) — The customer's custom fields list.
- `_expandable` (array, **required**) — The extra-field's list that are not expanded and can be expanded into objects.

Example:
```json
{
  "id": 1472289,
  "customer_name": "Bob Marley",
  "fully_qualified_name": "Bob Marley",
  "parent_customer": "Jerry Wheeler",
  "account_number": "30000",
  "account_balance": 10.34,
  "private_notes": "None",
  "public_notes": "None",
  "credit_rating": "A+",
  "labor_charge_type": "flat",
  "labor_charge_default_rate": 50.45,
  "last_serviced_date": "2018-08-07",
  "is_bill_for_drive_time": true,
  "is_vip": true,
  "referral_source": "Google AdWords",
  "agent": "John Theowner",
  "discount": 10.23,
  "discount_type": "%",
  "payment_type": "Check",
  "payment_terms": "DUR",
  "assigned_contract": "Retail Service Contract",
  "industry": "Advertising Agencies",
  "is_taxable": false,
  "tax_item_name": "Sanity Tax",
  "qbo_sync_token": 385,
  "qbo_currency": "USD",
  "qbo_id": null,
  "qbd_id": null,
  "created_at": "2018-08-07T18:31:28+00:00",
  "updated_at": "2018-08-07T18:31:28+00:00",
  "contacts": [
    {
      "prefix": "Mr.",
      "fname": "Jerry",
      "lname": "Wheeler",
      "suffix": "suf",
      "contact_type": "Billing",
      "dob": "April 19",
      "anniversary": "October 4",
      "job_title": "Manager",
      "department": "executive",
      "created_at": "2016-12-21T14:12:08+00:00",
      "updated_at": "2016-12-21T14:12:08+00:00",
      "is_primary": true,
      "phones": [
        {
          "phone": "066-361-8172",
          "ext": 38,
          "type": "Mobile",
          "created_at": "2018-10-05T11:51:48+00:00",
          "updated_at": "2018-10-05T11:54:09+00:00",
          "is_mobile": true
        }
      ],
      "emails": [
        {
          "email": "anton.lyubch1@gmail.com",
          "class": "Personal",
          "types_accepted": "CONF,PMT",
          "created_at": "2018-10-05T11:51:48+00:00",
          "updated_at": "2018-10-05T11:54:09+00:00"
        }
      ]
    }
  ],
  "locations": [
    {
      "street_1": "1904 Industrial Blvd",
      "street_2": "103",
      "city": "Colleyville",
      "state_prov": "Texas",
      "postal_code": "76034",
      "country": "USA",
      "nickname": "Office",
      "gate_instructions": "Gate instructions",
      "latitude": 123.45,
      "longitude": 67.89,
      "location_type": "home",
      "created_at": "2018-08-07T18:31:28+00:00",
      "updated_at": "2018-08-07T18:31:28+00:00",
      "is_primary": false,
      "is_gated": false,
      "is_bill_to": false,
      "customer_contact": "Sam Smith"
    }
  ],
  "custom_fields": [
    {
      "name": "Text",
      "value": "Example text value",
      "type": "text",
      "group": "Default",
      "created_at": "2018-10-11T11:52:33+00:00",
      "updated_at": "2018-10-11T11:52:33+00:00",
      "is_required": true
    }
  ],
  "_expandable": [
    "contacts",
    "contacts.phones",
    "contacts.emails",
    "locations",
    "custom_fields"
  ]
}
```

**Response 400:**
### 400 Bad Request (Client Error) The server cannot or will not process the request due to an apparent client error (e.g., malformed request syntax, size too large, invalid request message framing, or deceptive request routing).
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 400,
  "name": "Bad Request.",
  "message": "Your request is invalid."
}
```

**Response 401:**
### 401 Unauthorized (Client Error) Authentication is required and has failed or has not yet been provided.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 401,
  "name": "Unauthorized.",
  "message": "Your request was made with invalid credentials."
}
```

**Response 403:**
### 403 Forbidden (Client Error) Access to the requested resource is forbidden. The server understood the request, but will not fulfill it.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 403,
  "name": "Forbidden.",
  "message": "Login Required."
}
```

**Response 404:**
### 404 Not Found (Client Error) The requested resource could not be found but may be available in the future.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 404,
  "name": "Not Found.",
  "message": "Item not found."
}
```

**Response 405:**
### 405 Method Not Allowed (Client Error) A request method is not supported for the requested resource. For example, a GET request on a form that requires data to be presented via POST.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 405,
  "name": "Method not allowed.",
  "message": "Method Not Allowed. This url can only handle the following request methods: GET.\n"
}
```

**Response 415:**
### 415 Unsupported Media Type (Client Error) The request entity has a media type which the server or resource does not support. For example, the client set request data as `application/xml`, but the server requires that request data use a different format.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 415,
  "name": "Unsupported Media Type.",
  "message": "None of your requested content types is supported."
}
```

**Response 429:**
### 429 Too Many Requests (Client Error) The user has sent too many requests in a given amount of time.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 429,
  "name": "Too Many Requests.",
  "message": "Rate limit exceeded."
}
```

**Response 500:**
### 500 Internal Server Error (Server Error) A generic error message, given when an unexpected condition was encountered and no more specific message is suitable.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 500,
  "name": "Internal server error.",
  "message": "Failed to create the object for unknown reason."
}
```

### GET `/v1/customers/{customer-id}/equipment`

List all Equipment matching query criteria, if provided,
otherwise list all Equipment.

*Traits:* tra.equipment-fieldable, tra.equipment-sortable, tra.equipment-filtrable, tra.formatable

**Query Parameters:**

- `page` (integer, optional) (default: `1`) — Used to send a page number to be displayed. Example: `2`
- `per-page` (integer, optional) (default: `10`) — Used to send a number of items displayed per page (min `1`, max `50`). Example: `20`
- `fields` (string, optional) (default: `If not passed, will be displayed all available.`) Enum: `id`, `type`, `make`, `model`, `sku`, `serial_number`, `location`, `notes`, `extended_warranty_provider`, `is_extended_warranty`, `extended_warranty_date`, `warranty_date`, `install_date`, `created_at`, `updated_at`, `customer_id`, `customer`, `customer_location` — Used to send a list of fields to be displayed. Accepted value is comma-separated string. Example: `id,location,customer_location`
- `expand` (string, optional) (default: `If not passed, will be displayed nothing.`) Enum: `custom_fields` — Used to send a list of extra-fields to be displayed. Accepted value is comma-separated string. Example: `custom_fields`
- `sort` (string, optional) (default: `id`) Enum: `id`, `type`, `make`, `model`, `sku`, `serial_number`, `location`, `notes`, `extended_warranty_provider`, `is_extended_warranty`, `extended_warranty_date`, `warranty_date`, `install_date`, `created_at`, `updated_at`, `customer_id`, `customer`, `customer_location` — Used to sort the results by given fields. Use minus `-` before field name to sort DESC. Accepted value is comma-separated string. Example: `created_at,-type`
- `format` (string, optional) (default: `json`) Enum: `json`, `xml` — Used to send a format of data of the response. Do not use together with the `Accept` header.
- `access_token` (string, optional) — Used to send a valid OAuth 2 access token. Do not use together with the `Authorization` header. Example: `eyJz93a...k4laUWw`

**Response 200:**
### 200 OK (Success) Standard response for successful HTTP requests.
- Type: `object`

- `items` (array, **required**) — Collection envelope.
- `_expandable` (array, **required**) — The extra-field's list that are not expanded and can be expanded into objects.
- `_meta` (object, **required**) — Meta information.
  - `totalCount` (integer, optional) — Total number of data items.
  - `pageCount` (integer, optional) — Total number of pages of data.
  - `currentPage` (integer, optional) — The current page number (1-based).
  - `perPage` (integer, optional) — The number of data items in each page.

Example:
```json
{
  "items": [
    {
      "id": 12,
      "type": "Test Equipment",
      "make": "New Test Manufacturer",
      "model": "TST1231MOD",
      "sku": "SK15432",
      "serial_number": "1231#SRN",
      "location": "Test Location",
      "notes": "Test notes for the Test Equipment",
      "extended_warranty_provider": "Test War Provider",
      "is_extended_warranty": false,
      "extended_warranty_date": "2015-02-17",
      "warranty_date": "2015-01-16",
      "install_date": "2014-12-15",
      "created_at": "2015-01-16T11:31:49+00:00",
      "updated_at": "2015-01-16T11:31:49+00:00",
      "customer_id": 87,
      "customer": "John Theowner",
      "customer_location": "Office",
      "custom_fields": [
        {
          "name": "Text",
          "value": "Example text value",
          "type": "text",
          "group": "Default",
          "created_at": "2018-10-11T11:52:33+00:00",
          "updated_at": "2018-10-11T11:52:33+00:00",
          "is_required": true
        }
      ]
    }
  ],
  "_expandable": [
    "custom_fields"
  ],
  "_meta": {
    "totalCount": 50,
    "pageCount": 5,
    "currentPage": 1,
    "perPage": 10
  }
}
```

**Response 400:**
### 400 Bad Request (Client Error) The server cannot or will not process the request due to an apparent client error (e.g., malformed request syntax, size too large, invalid request message framing, or deceptive request routing).
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 400,
  "name": "Bad Request.",
  "message": "Your request is invalid."
}
```

**Response 401:**
### 401 Unauthorized (Client Error) Authentication is required and has failed or has not yet been provided.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 401,
  "name": "Unauthorized.",
  "message": "Your request was made with invalid credentials."
}
```

**Response 403:**
### 403 Forbidden (Client Error) Access to the requested resource is forbidden. The server understood the request, but will not fulfill it.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 403,
  "name": "Forbidden.",
  "message": "Login Required."
}
```

**Response 405:**
### 405 Method Not Allowed (Client Error) A request method is not supported for the requested resource. For example, a GET request on a form that requires data to be presented via POST.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 405,
  "name": "Method not allowed.",
  "message": "Method Not Allowed. This url can only handle the following request methods: GET.\n"
}
```

**Response 415:**
### 415 Unsupported Media Type (Client Error) The request entity has a media type which the server or resource does not support. For example, the client set request data as `application/xml`, but the server requires that request data use a different format.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 415,
  "name": "Unsupported Media Type.",
  "message": "None of your requested content types is supported."
}
```

**Response 429:**
### 429 Too Many Requests (Client Error) The user has sent too many requests in a given amount of time.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 429,
  "name": "Too Many Requests.",
  "message": "Rate limit exceeded."
}
```

**Response 500:**
### 500 Internal Server Error (Server Error) A generic error message, given when an unexpected condition was encountered and no more specific message is suitable.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 500,
  "name": "Internal server error.",
  "message": "Failed to create the object for unknown reason."
}
```

### GET `/v1/customers/{customer-id}/equipment/{equipment-id}`

Get a Equipment by identifier.

*Traits:* tra.equipment-fieldable, tra.formatable

**URI Parameters:**

- `equipment-id` (integer, **required**) — Used to send an identifier of the Equipment to be used.

**Query Parameters:**

- `fields` (string, optional) (default: `If not passed, will be displayed all available.`) Enum: `id`, `type`, `make`, `model`, `sku`, `serial_number`, `location`, `notes`, `extended_warranty_provider`, `is_extended_warranty`, `extended_warranty_date`, `warranty_date`, `install_date`, `created_at`, `updated_at`, `customer_id`, `customer`, `customer_location` — Used to send a list of fields to be displayed. Accepted value is comma-separated string. Example: `id,location,customer_location`
- `expand` (string, optional) (default: `If not passed, will be displayed nothing.`) Enum: `custom_fields` — Used to send a list of extra-fields to be displayed. Accepted value is comma-separated string. Example: `custom_fields`
- `format` (string, optional) (default: `json`) Enum: `json`, `xml` — Used to send a format of data of the response. Do not use together with the `Accept` header.
- `access_token` (string, optional) — Used to send a valid OAuth 2 access token. Do not use together with the `Authorization` header. Example: `eyJz93a...k4laUWw`

**Response 200:**
### 200 OK (Success) Standard response for successful HTTP requests.
- Type: `object`

- `id` (integer, optional) — The equipment's identifier.
- `type` (string, optional) — The equipment's type.
- `make` (string, optional) — The equipment's make.
- `model` (string, optional) — The equipment's model.
- `sku` (string, optional) — The equipment's sku.
- `serial_number` (string, optional) — The equipment's serial number.
- `location` (string, optional) — The equipment's location.
- `notes` (string, optional) — The equipment's notes.
- `extended_warranty_provider` (string, optional) — The equipment's extended warranty provider.
- `is_extended_warranty` (boolean, optional) — The equipment's is extended warranty flag.
- `extended_warranty_date` (datetime, optional) — The equipment's extended warranty date.
- `warranty_date` (datetime, optional) — The equipment's warranty date.
- `install_date` (datetime, optional) — The equipment's install date.
- `created_at` (datetime, optional) — The equipment's created date.
- `updated_at` (datetime, optional) — The equipment's updated date.
- `customer_id` (integer, optional) — The `id` of attached customer to the equipment (Note: `id` - [integer] the customer's identifier).
- `customer` (string, optional) — The `header` of attached customer to the equipment (Note: `header` - [string] the customer's fields concatenated by pattern `{customer_name}`).
- `customer_location` (string, optional) — The `header` of attached customer location to the equipment (Note: `header` - [string] the customer location's fields concatenated by pattern `{nickname} {street_1} {city}` with space as separator).
- `custom_fields` (array, optional) — The equipment's custom fields list.
- `_expandable` (array, **required**) — The extra-field's list that are not expanded and can be expanded into objects.

Example:
```json
{
  "id": 12,
  "type": "Test Equipment",
  "make": "New Test Manufacturer",
  "model": "TST1231MOD",
  "sku": "SK15432",
  "serial_number": "1231#SRN",
  "location": "Test Location",
  "notes": "Test notes for the Test Equipment",
  "extended_warranty_provider": "Test War Provider",
  "is_extended_warranty": false,
  "extended_warranty_date": "2015-02-17",
  "warranty_date": "2015-01-16",
  "install_date": "2014-12-15",
  "created_at": "2015-01-16T11:31:49+00:00",
  "updated_at": "2015-01-16T11:31:49+00:00",
  "customer_id": 87,
  "customer": "John Theowner",
  "customer_location": "Office",
  "custom_fields": [
    {
      "name": "Text",
      "value": "Example text value",
      "type": "text",
      "group": "Default",
      "created_at": "2018-10-11T11:52:33+00:00",
      "updated_at": "2018-10-11T11:52:33+00:00",
      "is_required": true
    }
  ],
  "_expandable": [
    "custom_fields"
  ]
}
```

**Response 400:**
### 400 Bad Request (Client Error) The server cannot or will not process the request due to an apparent client error (e.g., malformed request syntax, size too large, invalid request message framing, or deceptive request routing).
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 400,
  "name": "Bad Request.",
  "message": "Your request is invalid."
}
```

**Response 401:**
### 401 Unauthorized (Client Error) Authentication is required and has failed or has not yet been provided.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 401,
  "name": "Unauthorized.",
  "message": "Your request was made with invalid credentials."
}
```

**Response 403:**
### 403 Forbidden (Client Error) Access to the requested resource is forbidden. The server understood the request, but will not fulfill it.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 403,
  "name": "Forbidden.",
  "message": "Login Required."
}
```

**Response 404:**
### 404 Not Found (Client Error) The requested resource could not be found but may be available in the future.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 404,
  "name": "Not Found.",
  "message": "Item not found."
}
```

**Response 405:**
### 405 Method Not Allowed (Client Error) A request method is not supported for the requested resource. For example, a GET request on a form that requires data to be presented via POST.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 405,
  "name": "Method not allowed.",
  "message": "Method Not Allowed. This url can only handle the following request methods: GET.\n"
}
```

**Response 415:**
### 415 Unsupported Media Type (Client Error) The request entity has a media type which the server or resource does not support. For example, the client set request data as `application/xml`, but the server requires that request data use a different format.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 415,
  "name": "Unsupported Media Type.",
  "message": "None of your requested content types is supported."
}
```

**Response 429:**
### 429 Too Many Requests (Client Error) The user has sent too many requests in a given amount of time.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 429,
  "name": "Too Many Requests.",
  "message": "Rate limit exceeded."
}
```

**Response 500:**
### 500 Internal Server Error (Server Error) A generic error message, given when an unexpected condition was encountered and no more specific message is suitable.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 500,
  "name": "Internal server error.",
  "message": "Failed to create the object for unknown reason."
}
```

### /jobs

### POST `/v1/jobs`

Create a new Job.

*Traits:* tra.job-fieldable, tra.formatable

**Query Parameters:**

- `fields` (string, optional) (default: `If not passed, will be displayed all available.`) Enum: `id`, `number`, `check_number`, `priority`, `description`, `tech_notes`, `completion_notes`, `payment_status`, `taxes_fees_total`, `drive_labor_total`, `billable_expenses_total`, `total`, `payments_deposits_total`, `due_total`, `cost_total`, `duration`, `time_frame_promised_start`, `time_frame_promised_end`, `start_date`, `end_date`, `created_at`, `updated_at`, `closed_at`, `customer_id`, `customer_name`, `parent_customer`, `status`, `sub_status`, `contact_first_name`, `contact_last_name`, `street_1`, `street_2`, `city`, `state_prov`, `postal_code`, `location_name`, `is_gated`, `gate_instructions`, `category`, `source`, `payment_type`, `customer_payment_terms`, `project`, `phase`, `po_number`, `contract`, `note_to_customer`, `called_in_by`, `is_requires_follow_up` — Used to send a list of fields to be displayed. Accepted value is comma-separated string. Example: `id,number,description`
- `expand` (string, optional) (default: `If not passed, will be displayed nothing.`) Enum: `agents`, `custom_fields`, `pictures`, `documents`, `equipment`, `equipment.custom_fields`, `techs_assigned`, `tasks`, `notes`, `products`, `services`, `other_charges`, `labor_charges`, `expenses`, `payments`, `invoices`, `signatures`, `printable_work_order`, `visits`, `visits.techs_assigned` — Used to send a list of extra-fields to be displayed. Accepted value is comma-separated string. Example: `agents,equipment.custom_fields,visits.techs_assigned`
- `format` (string, optional) (default: `json`) Enum: `json`, `xml` — Used to send a format of data of the response. Do not use together with the `Accept` header.
- `access_token` (string, optional) — Used to send a valid OAuth 2 access token. Do not use together with the `Authorization` header. Example: `eyJz93a...k4laUWw`

**Request Body** (`0`):
- Type: `object`

- `check_number` (string, optional) — Used to send the job's check number that will be set.
- `priority` (string, optional) (default: `Normal`) Enum: `Low`, `Normal`, `High` — Used to send the job's priority that will be set.
- `description` (string, optional) — Used to send the job's description that will be set.
- `tech_notes` (string, optional) — Used to send the job's tech notes that will be set.
- `completion_notes` (string, optional) — Used to send the job's completion notes that will be set.
- `duration` (integer, optional) (default: `3600`) — Used to send the job's duration (in seconds) that will be set.
- `time_frame_promised_start` (string, optional) — Used to send the job's time frame promised start that will be set.
- `time_frame_promised_end` (string, optional) — Used to send the job's time frame promised end that will be set.
- `start_date` (datetime, optional) — Used to send the job's start date that will be set.
- `end_date` (datetime, optional) — Used to send the job's end date that will be set.
- `customer_name` (string, **required**) — Used to send a customer's `id` or `header` that will be attached to the job (Note: `id` - [integer] the customer's identifier, `header` - [string] the customer's fields concatenated by pattern `{customer_name}`).
- `status` (string, optional) (default: `If not passed, it takes the default status for jobs.`) — Used to send a status'es `id` or `header` that will be attached to the job (Note: `id` - [integer] the status'es identifier, `header` - [string] the status'es fields concatenated by pattern `{name}`). Optionally required (configurable into the company preferences).
- `contact_first_name` (string, optional) (default: `If not passed, it takes the first name from primary contact of the customer (if exists), otherwise a primary contact will be created for the customer.`) — Used to send the job's contact first name that will be set. If a contact with the passed name and surname already exists, then a new contact will not be created, but the existing one will be attached.
- `contact_last_name` (string, optional) (default: `If not passed, it takes the last name from primary contact of the customer (if exists), otherwise a primary contact will be created for the customer.`) — Used to send the job's contact last name that will be set. If a contact with the passed name and surname already exists, then a new contact will not be created, but the existing one will be attached.
- `street_1` (string, optional) (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) — Used to send the job's location street 1 that will be set.
- `street_2` (string, optional) (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) — Used to send the job's location street 2 that will be set.
- `city` (string, optional) (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) — Used to send the job's location city that will be set.
- `state_prov` (string, optional) (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) — Used to send the job's location state prov that will be set.
- `postal_code` (string, optional) (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) — Used to send the job's location postal code that will be set.
- `location_name` (string, optional) (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) — Used to send the job's location name that will be set.
- `is_gated` (boolean, optional) (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) — Used to send the job's location is gated flag that will be set.
- `gate_instructions` (string, optional) (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) — Used to send the job's location gate instructions that will be set.
- `category` (string, optional) — Used to send a category's `id` or `header` that will be attached to the job (Note: `id` - [integer] the category's identifier, `header` - [string] the category's fields concatenated by pattern `{category}`). Optionally required (configurable into the company preferences).
- `source` (string, optional) (default: `If not passed, it takes the value from the customer.`) — Used to send a source's `id` or `header` that will be attached to the job (Note: `id` - [integer] the source's identifier, `header` - [string] the source's fields concatenated by pattern `{short_name}`).
- `payment_type` (string, optional) (default: `If not passed, it takes the value from the customer.`) — Used to send a payment type's `id` or `header` that will be attached to the job (Note: `id` - [integer] the payment type's identifier, `header` - [string] the payment type's fields concatenated by pattern `{short_name}`). Optionally required (configurable into the company preferences).
- `customer_payment_terms` (string, optional) (default: `If not passed, it takes the value from the customer.`) — Used to send a customer payment term's `id` or `header` that will be attached to the job (Note: `id` - [integer] the customer payment term's identifier, `header` - [string] the customer payment term's fields concatenated by pattern `{name}`).
- `project` (string, optional) — Used to send a project's `id` or `header` that will be attached to the job (Note: `id` - [integer] the project's identifier, `header` - [string] the project's fields concatenated by pattern `{name}`).
- `phase` (string, optional) — Used to send a phase's `id` or `header` that will be attached to the job (Note: `id` - [integer] the phase's identifier, `header` - [string] the phase's fields concatenated by pattern `{name}`).
- `po_number` (string, optional) — Used to send the job's po number that will be set.
- `contract` (string, optional) (default: `If not passed, it takes the value from the customer.`) — Used to send a contract's `id` or `header` that will be attached to the job (Note: `id` - [integer] the contract's identifier, `header` - [string] the contract's fields concatenated by pattern `{contract_title}`).
- `note_to_customer` (string, optional) (default: `If not passed, it takes the value from the company preferences.`) — Used to send the job's note to customer that will be set.
- `called_in_by` (string, optional) — Used to send the job's called in by that will be set.
- `is_requires_follow_up` (boolean, optional) — Used to send the job's is requires follow up flag that will be set.
- `agents` (array, optional) (default: `array`) — Used to send the job's agents list that will be set.
- `custom_fields` (array, optional) (default: `If some custom field (configured into the custom fields settings) not passed, it creates the new one with its default value.`) — Used to send the job's custom fields list that will be set.
- `equipment` (array, optional) (default: `array`) — Used to send the job's equipments list that will be set.
- `techs_assigned` (array, optional) (default: `array`) — Used to send the job's techs assigned list that will be set.
- `tasks` (array, optional) (default: `array`) — Used to send the job's tasks list that will be set.
- `notes` (array, optional) (default: `array`) — Used to send the job's notes list that will be set.
- `products` (array, optional) (default: `array`) — Used to send the job's products list that will be set.
- `services` (array, optional) (default: `array`) — Used to send the job's services list that will be set.
- `other_charges` (array, optional) (default: `If not passed, it creates all entries with `auto added` option enabled. Also it creates all not passed other charges declared into `products` and `services`.`) — Used to send the job's other charges list that will be set.
- `labor_charges` (array, optional) (default: `array`) — Used to send the job's labor charges list that will be set.
- `expenses` (array, optional) (default: `array`) — Used to send the job's expenses list that will be set.

**Response 201:**
### 201 Created (Success) The request has been fulfilled, resulting in the creation of a new resource.
- Type: `object`

- `id` (integer, optional) — The job's identifier.
- `number` (string, optional) — The job's number.
- `check_number` (string, optional) — The job's check number.
- `priority` (string, optional) — The job's priority.
- `description` (string, optional) — The job's description.
- `tech_notes` (string, optional) — The job's tech notes.
- `completion_notes` (string, optional) — The job's completion notes.
- `payment_status` (string, optional) — The job's payment status.
- `taxes_fees_total` (number, optional) — The job's taxes and fees total.
- `drive_labor_total` (number, optional) — The job's drive and labor total.
- `billable_expenses_total` (number, optional) — The job's billable expenses total.
- `total` (number, optional) — The job's total.
- `payments_deposits_total` (number, optional) — The job's payments and deposits total.
- `due_total` (number, optional) — The job's due total.
- `cost_total` (number, optional) — The job's cost total.
- `duration` (integer, optional) — The job's duration (in seconds).
- `time_frame_promised_start` (string, optional) — The job's time frame promised start.
- `time_frame_promised_end` (string, optional) — The job's time frame promised end.
- `start_date` (datetime, optional) — The job's start date.
- `end_date` (datetime, optional) — The job's end date.
- `created_at` (datetime, optional) — The job's created date.
- `updated_at` (datetime, optional) — The job's updated date.
- `closed_at` (datetime, optional) — The job's closed date.
- `customer_id` (integer, optional) — The `id` of attached customer to the job (Note: `id` - [integer] the customer's identifier).
- `customer_name` (string, optional) — The `header` of attached customer to the job (Note: `header` - [string] the customer's fields concatenated by pattern `{customer_name}`).
- `parent_customer` (string, optional) — The `header` of attached parent customer to the job (Note: `header` - [string] the parent customer's fields concatenated by pattern `{customer_name}`).
- `status` (string, optional) — The `header` of attached status to the job (Note: `header` - [string] the status'es fields concatenated by pattern `{name}`).
- `sub_status` (string, optional) — The `header` of attached sub status to the job (Note: `header` - [string] the sub status's fields concatenated by pattern `{name}`).
- `contact_first_name` (string, optional) — The job's contact first name.
- `contact_last_name` (string, optional) — The job's contact last name.
- `street_1` (string, optional) — The job's location street 1.
- `street_2` (string, optional) — The job's location street 2.
- `city` (string, optional) — The job's location city.
- `state_prov` (string, optional) — The job's location state prov.
- `postal_code` (string, optional) — The job's location postal code.
- `location_name` (string, optional) — The job's location name.
- `is_gated` (boolean, optional) — The job's location is gated flag.
- `gate_instructions` (string, optional) — The job's location gate instructions.
- `category` (string, optional) — The `header` of attached category to the job (Note: `header` - [string] the category's fields concatenated by pattern `{category}`).
- `source` (string, optional) — The `header` of attached source to the job (Note: `header` - [string] the source's fields concatenated by pattern `{short_name}`).
- `payment_type` (string, optional) — The `header` of attached payment type to the job (Note: `header` - [string] the payment type's fields concatenated by pattern `{short_name}`).
- `customer_payment_terms` (string, optional) — The `header` of attached customer payment term to the job (Note: `header` - [string] the customer payment term's fields concatenated by pattern `{name}`).
- `project` (string, optional) — The `header` of attached project to the job (Note: `header` - [string] the project's fields concatenated by pattern `{name}`).
- `phase` (string, optional) — The `header` of attached phase to the job (Note: `header` - [string] the phase's fields concatenated by pattern `{name}`).
- `po_number` (string, optional) — The job's po number.
- `contract` (string, optional) — The `header` of attached contract to the job (Note: `header` - [string] the contract's fields concatenated by pattern `{contract_title}`).
- `note_to_customer` (string, optional) — The job's note to customer.
- `called_in_by` (string, optional) — The job's called in by.
- `is_requires_follow_up` (boolean, optional) — The job's is requires follow up flag.
- `agents` (array, optional) — The job's agents list.
- `custom_fields` (array, optional) — The job's custom fields list.
- `pictures` (array, optional) — The job's pictures list.
- `documents` (array, optional) — The job's documents list.
- `equipment` (array, optional) — The job's equipments list.
- `techs_assigned` (array, optional) — The job's techs assigned list.
- `tasks` (array, optional) — The job's tasks list.
- `notes` (array, optional) — The job's notes list.
- `products` (array, optional) — The job's products list.
- `services` (array, optional) — The job's services list.
- `other_charges` (array, optional) — The job's other charges list.
- `labor_charges` (array, optional) — The job's labor charges list.
- `expenses` (array, optional) — The job's expenses list.
- `payments` (array, optional) — The job's payments list.
- `invoices` (array, optional) — The job's invoices list.
- `signatures` (array, optional) — The job's signatures list.
- `printable_work_order` (array, optional) — The job's printable work order list.
- `visits` (array, optional) — The job's visits list.
- `_expandable` (array, **required**) — The extra-field's list that are not expanded and can be expanded into objects.

**Response 400:**
### 400 Bad Request (Client Error) The server cannot or will not process the request due to an apparent client error (e.g., malformed request syntax, size too large, invalid request message framing, or deceptive request routing).
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 400,
  "name": "Bad Request.",
  "message": "Your request is invalid."
}
```

**Response 401:**
### 401 Unauthorized (Client Error) Authentication is required and has failed or has not yet been provided.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 401,
  "name": "Unauthorized.",
  "message": "Your request was made with invalid credentials."
}
```

**Response 403:**
### 403 Forbidden (Client Error) Access to the requested resource is forbidden. The server understood the request, but will not fulfill it.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 403,
  "name": "Forbidden.",
  "message": "Login Required."
}
```

**Response 405:**
### 405 Method Not Allowed (Client Error) A request method is not supported for the requested resource. For example, a GET request on a form that requires data to be presented via POST.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 405,
  "name": "Method not allowed.",
  "message": "Method Not Allowed. This url can only handle the following request methods: GET.\n"
}
```

**Response 415:**
### 415 Unsupported Media Type (Client Error) The request entity has a media type which the server or resource does not support. For example, the client set request data as `application/xml`, but the server requires that request data use a different format.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 415,
  "name": "Unsupported Media Type.",
  "message": "None of your requested content types is supported."
}
```

**Response 422:**
### 422 Unprocessable Entity (Client Error) The request was well-formed but was unable to be followed due to semantic errors.
- Type: `array`

Example:
```json
[
  {
    "field": "name",
    "message": "Name is too long (maximum is 45 characters)."
  }
]
```

**Response 429:**
### 429 Too Many Requests (Client Error) The user has sent too many requests in a given amount of time.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 429,
  "name": "Too Many Requests.",
  "message": "Rate limit exceeded."
}
```

**Response 500:**
### 500 Internal Server Error (Server Error) A generic error message, given when an unexpected condition was encountered and no more specific message is suitable.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 500,
  "name": "Internal server error.",
  "message": "Failed to create the object for unknown reason."
}
```

### GET `/v1/jobs`

List all Jobs matching query criteria, if provided,
otherwise list all Jobs.

*Traits:* tra.job-fieldable, tra.job-sortable, tra.job-filtrable, tra.formatable

**Query Parameters:**

- `page` (integer, optional) (default: `1`) — Used to send a page number to be displayed. Example: `2`
- `per-page` (integer, optional) (default: `10`) — Used to send a number of items displayed per page (min `1`, max `50`). Example: `20`
- `fields` (string, optional) (default: `If not passed, will be displayed all available.`) Enum: `id`, `number`, `check_number`, `priority`, `description`, `tech_notes`, `completion_notes`, `payment_status`, `taxes_fees_total`, `drive_labor_total`, `billable_expenses_total`, `total`, `payments_deposits_total`, `due_total`, `cost_total`, `duration`, `time_frame_promised_start`, `time_frame_promised_end`, `start_date`, `end_date`, `created_at`, `updated_at`, `closed_at`, `customer_id`, `customer_name`, `parent_customer`, `status`, `sub_status`, `contact_first_name`, `contact_last_name`, `street_1`, `street_2`, `city`, `state_prov`, `postal_code`, `location_name`, `is_gated`, `gate_instructions`, `category`, `source`, `payment_type`, `customer_payment_terms`, `project`, `phase`, `po_number`, `contract`, `note_to_customer`, `called_in_by`, `is_requires_follow_up` — Used to send a list of fields to be displayed. Accepted value is comma-separated string. Example: `id,number,description`
- `expand` (string, optional) (default: `If not passed, will be displayed nothing.`) Enum: `agents`, `custom_fields`, `pictures`, `documents`, `equipment`, `equipment.custom_fields`, `techs_assigned`, `tasks`, `notes`, `products`, `services`, `other_charges`, `labor_charges`, `expenses`, `payments`, `invoices`, `signatures`, `printable_work_order`, `visits`, `visits.techs_assigned` — Used to send a list of extra-fields to be displayed. Accepted value is comma-separated string. Example: `agents,equipment.custom_fields,visits.techs_assigned`
- `sort` (string, optional) (default: `id`) Enum: `id`, `number`, `po_number`, `check_number`, `description`, `tech_notes`, `completion_notes`, `duration`, `time_frame_promised_start`, `time_frame_promised_end`, `start_date`, `end_date`, `created_at`, `updated_at`, `closed_at`, `customer_id`, `customer_name`, `status`, `sub_status`, `category`, `source`, `payment_type`, `customer_payment_terms`, `contract`, `called_in_by` — Used to sort the results by given fields. Use minus `-` before field name to sort DESC. Accepted value is comma-separated string. Example: `number,-start_date`
- `filters[status]` (string, optional) — Used to filter results by given statuses (full match). Accepted value is comma-separated string. Example: `Job Closed, Cancelled`
- `filters[number]` (string, optional) — Used to filter results by given number (partial match). Example: `101`
- `filters[po_number]` (string, optional) — Used to filter results by given po number (partial match). Example: `101`
- `filters[invoice_number]` (string, optional) — Used to filter results by given invoice number (partial match). Example: `101`
- `filters[customer_name]` (string, optional) — Used to filter results by given customer's name (partial match). Example: `John Walter`
- `filters[parent_customer_name]` (string, optional) — Used to filter results by given parent customer's name (partial match). Example: `John Walter`
- `filters[contact_first_name]` (string, optional) — Used to filter results by given contact's first name (partial match). Example: `John`
- `filters[contact_last_name]` (string, optional) — Used to filter results by given contact's last name (partial match). Example: `Walter`
- `filters[address]` (string, optional) — Used to filter results by given address (partial match). Example: `3210 Midway Ave`
- `filters[city]` (string, optional) — Used to filter results by given city (full match). Example: `Dallas`
- `filters[zip_code]` (integer, optional) — Used to filter results by given zip code (full match). Example: `75242`
- `filters[phone]` (string, optional) — Used to filter results by given phone (partial match). Example: `214-555-1212`
- `filters[email]` (string, optional) — Used to filter results by given email (full match). Example: `john.walter@gmail.com`
- `filters[category]` (string, optional) — Used to filter results by given categories (full match). Accepted value is comma-separated string. Example: `Install, Service Call`
- `filters[source]` (string, optional) — Used to filter results by given sources (full match). Accepted value is comma-separated string. Example: `Google, Yelp`
- `filters[start_date][lte]` (string, optional) — Used to filter results by given `less than or equal` of start date (format: `Y-m-d`). Example: `2002-10-02`
- `filters[start_date][gte]` (string, optional) — Used to filter results by given `greater than or equal` of start date (format: `Y-m-d`). Example: `2002-10-02`
- `filters[end_date][lte]` (string, optional) — Used to filter results by given `less than or equal` of end date (format: `Y-m-d`). Example: `2002-10-02`
- `filters[end_date][gte]` (string, optional) — Used to filter results by given `greater than or equal` of end date (format: `Y-m-d`). Example: `2002-10-02`
- `filters[updated_date][lte]` (string, optional) — Used to filter results by given `less than or equal` of updated date (format `RFC 3339`: `Y-m-d\TH:i:sP`). Example: `2002-10-02T10:00:00-05:00`
- `filters[updated_date][gte]` (string, optional) — Used to filter results by given `greater than or equal` of updated date (format `RFC 3339`: `Y-m-d\TH:i:sP`). Example: `2002-10-02T10:00:00-05:00`
- `filters[closed_date][lte]` (string, optional) — Used to filter results by given `less than or equal` of closed date (format `RFC 3339`: `Y-m-d\TH:i:sP`). Example: `2002-10-02T10:00:00-05:00`
- `filters[closed_date][gte]` (string, optional) — Used to filter results by given `greater than or equal` of closed date (format `RFC 3339`: `Y-m-d\TH:i:sP`). Example: `2002-10-02T10:00:00-05:00`
- `format` (string, optional) (default: `json`) Enum: `json`, `xml` — Used to send a format of data of the response. Do not use together with the `Accept` header.
- `access_token` (string, optional) — Used to send a valid OAuth 2 access token. Do not use together with the `Authorization` header. Example: `eyJz93a...k4laUWw`

**Response 200:**
### 200 OK (Success) Standard response for successful HTTP requests.
- Type: `object`

- `items` (array, **required**) — Collection envelope.
- `_expandable` (array, **required**) — The extra-field's list that are not expanded and can be expanded into objects.
- `_meta` (object, **required**) — Meta information.
  - `totalCount` (integer, optional) — Total number of data items.
  - `pageCount` (integer, optional) — Total number of pages of data.
  - `currentPage` (integer, optional) — The current page number (1-based).
  - `perPage` (integer, optional) — The number of data items in each page.

**Response 400:**
### 400 Bad Request (Client Error) The server cannot or will not process the request due to an apparent client error (e.g., malformed request syntax, size too large, invalid request message framing, or deceptive request routing).
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 400,
  "name": "Bad Request.",
  "message": "Your request is invalid."
}
```

**Response 401:**
### 401 Unauthorized (Client Error) Authentication is required and has failed or has not yet been provided.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 401,
  "name": "Unauthorized.",
  "message": "Your request was made with invalid credentials."
}
```

**Response 403:**
### 403 Forbidden (Client Error) Access to the requested resource is forbidden. The server understood the request, but will not fulfill it.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 403,
  "name": "Forbidden.",
  "message": "Login Required."
}
```

**Response 405:**
### 405 Method Not Allowed (Client Error) A request method is not supported for the requested resource. For example, a GET request on a form that requires data to be presented via POST.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 405,
  "name": "Method not allowed.",
  "message": "Method Not Allowed. This url can only handle the following request methods: GET.\n"
}
```

**Response 415:**
### 415 Unsupported Media Type (Client Error) The request entity has a media type which the server or resource does not support. For example, the client set request data as `application/xml`, but the server requires that request data use a different format.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 415,
  "name": "Unsupported Media Type.",
  "message": "None of your requested content types is supported."
}
```

**Response 429:**
### 429 Too Many Requests (Client Error) The user has sent too many requests in a given amount of time.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 429,
  "name": "Too Many Requests.",
  "message": "Rate limit exceeded."
}
```

**Response 500:**
### 500 Internal Server Error (Server Error) A generic error message, given when an unexpected condition was encountered and no more specific message is suitable.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 500,
  "name": "Internal server error.",
  "message": "Failed to create the object for unknown reason."
}
```

### GET `/v1/jobs/{job-id}`

Get a Job by identifier.

*Traits:* tra.job-fieldable, tra.formatable

**URI Parameters:**

- `job-id` (integer, **required**) — Used to send an identifier of the Job to be used.

**Query Parameters:**

- `fields` (string, optional) (default: `If not passed, will be displayed all available.`) Enum: `id`, `number`, `check_number`, `priority`, `description`, `tech_notes`, `completion_notes`, `payment_status`, `taxes_fees_total`, `drive_labor_total`, `billable_expenses_total`, `total`, `payments_deposits_total`, `due_total`, `cost_total`, `duration`, `time_frame_promised_start`, `time_frame_promised_end`, `start_date`, `end_date`, `created_at`, `updated_at`, `closed_at`, `customer_id`, `customer_name`, `parent_customer`, `status`, `sub_status`, `contact_first_name`, `contact_last_name`, `street_1`, `street_2`, `city`, `state_prov`, `postal_code`, `location_name`, `is_gated`, `gate_instructions`, `category`, `source`, `payment_type`, `customer_payment_terms`, `project`, `phase`, `po_number`, `contract`, `note_to_customer`, `called_in_by`, `is_requires_follow_up` — Used to send a list of fields to be displayed. Accepted value is comma-separated string. Example: `id,number,description`
- `expand` (string, optional) (default: `If not passed, will be displayed nothing.`) Enum: `agents`, `custom_fields`, `pictures`, `documents`, `equipment`, `equipment.custom_fields`, `techs_assigned`, `tasks`, `notes`, `products`, `services`, `other_charges`, `labor_charges`, `expenses`, `payments`, `invoices`, `signatures`, `printable_work_order`, `visits`, `visits.techs_assigned` — Used to send a list of extra-fields to be displayed. Accepted value is comma-separated string. Example: `agents,equipment.custom_fields,visits.techs_assigned`
- `format` (string, optional) (default: `json`) Enum: `json`, `xml` — Used to send a format of data of the response. Do not use together with the `Accept` header.
- `access_token` (string, optional) — Used to send a valid OAuth 2 access token. Do not use together with the `Authorization` header. Example: `eyJz93a...k4laUWw`

**Response 200:**
### 200 OK (Success) Standard response for successful HTTP requests.
- Type: `object`

- `id` (integer, optional) — The job's identifier.
- `number` (string, optional) — The job's number.
- `check_number` (string, optional) — The job's check number.
- `priority` (string, optional) — The job's priority.
- `description` (string, optional) — The job's description.
- `tech_notes` (string, optional) — The job's tech notes.
- `completion_notes` (string, optional) — The job's completion notes.
- `payment_status` (string, optional) — The job's payment status.
- `taxes_fees_total` (number, optional) — The job's taxes and fees total.
- `drive_labor_total` (number, optional) — The job's drive and labor total.
- `billable_expenses_total` (number, optional) — The job's billable expenses total.
- `total` (number, optional) — The job's total.
- `payments_deposits_total` (number, optional) — The job's payments and deposits total.
- `due_total` (number, optional) — The job's due total.
- `cost_total` (number, optional) — The job's cost total.
- `duration` (integer, optional) — The job's duration (in seconds).
- `time_frame_promised_start` (string, optional) — The job's time frame promised start.
- `time_frame_promised_end` (string, optional) — The job's time frame promised end.
- `start_date` (datetime, optional) — The job's start date.
- `end_date` (datetime, optional) — The job's end date.
- `created_at` (datetime, optional) — The job's created date.
- `updated_at` (datetime, optional) — The job's updated date.
- `closed_at` (datetime, optional) — The job's closed date.
- `customer_id` (integer, optional) — The `id` of attached customer to the job (Note: `id` - [integer] the customer's identifier).
- `customer_name` (string, optional) — The `header` of attached customer to the job (Note: `header` - [string] the customer's fields concatenated by pattern `{customer_name}`).
- `parent_customer` (string, optional) — The `header` of attached parent customer to the job (Note: `header` - [string] the parent customer's fields concatenated by pattern `{customer_name}`).
- `status` (string, optional) — The `header` of attached status to the job (Note: `header` - [string] the status'es fields concatenated by pattern `{name}`).
- `sub_status` (string, optional) — The `header` of attached sub status to the job (Note: `header` - [string] the sub status's fields concatenated by pattern `{name}`).
- `contact_first_name` (string, optional) — The job's contact first name.
- `contact_last_name` (string, optional) — The job's contact last name.
- `street_1` (string, optional) — The job's location street 1.
- `street_2` (string, optional) — The job's location street 2.
- `city` (string, optional) — The job's location city.
- `state_prov` (string, optional) — The job's location state prov.
- `postal_code` (string, optional) — The job's location postal code.
- `location_name` (string, optional) — The job's location name.
- `is_gated` (boolean, optional) — The job's location is gated flag.
- `gate_instructions` (string, optional) — The job's location gate instructions.
- `category` (string, optional) — The `header` of attached category to the job (Note: `header` - [string] the category's fields concatenated by pattern `{category}`).
- `source` (string, optional) — The `header` of attached source to the job (Note: `header` - [string] the source's fields concatenated by pattern `{short_name}`).
- `payment_type` (string, optional) — The `header` of attached payment type to the job (Note: `header` - [string] the payment type's fields concatenated by pattern `{short_name}`).
- `customer_payment_terms` (string, optional) — The `header` of attached customer payment term to the job (Note: `header` - [string] the customer payment term's fields concatenated by pattern `{name}`).
- `project` (string, optional) — The `header` of attached project to the job (Note: `header` - [string] the project's fields concatenated by pattern `{name}`).
- `phase` (string, optional) — The `header` of attached phase to the job (Note: `header` - [string] the phase's fields concatenated by pattern `{name}`).
- `po_number` (string, optional) — The job's po number.
- `contract` (string, optional) — The `header` of attached contract to the job (Note: `header` - [string] the contract's fields concatenated by pattern `{contract_title}`).
- `note_to_customer` (string, optional) — The job's note to customer.
- `called_in_by` (string, optional) — The job's called in by.
- `is_requires_follow_up` (boolean, optional) — The job's is requires follow up flag.
- `agents` (array, optional) — The job's agents list.
- `custom_fields` (array, optional) — The job's custom fields list.
- `pictures` (array, optional) — The job's pictures list.
- `documents` (array, optional) — The job's documents list.
- `equipment` (array, optional) — The job's equipments list.
- `techs_assigned` (array, optional) — The job's techs assigned list.
- `tasks` (array, optional) — The job's tasks list.
- `notes` (array, optional) — The job's notes list.
- `products` (array, optional) — The job's products list.
- `services` (array, optional) — The job's services list.
- `other_charges` (array, optional) — The job's other charges list.
- `labor_charges` (array, optional) — The job's labor charges list.
- `expenses` (array, optional) — The job's expenses list.
- `payments` (array, optional) — The job's payments list.
- `invoices` (array, optional) — The job's invoices list.
- `signatures` (array, optional) — The job's signatures list.
- `printable_work_order` (array, optional) — The job's printable work order list.
- `visits` (array, optional) — The job's visits list.
- `_expandable` (array, **required**) — The extra-field's list that are not expanded and can be expanded into objects.

**Response 400:**
### 400 Bad Request (Client Error) The server cannot or will not process the request due to an apparent client error (e.g., malformed request syntax, size too large, invalid request message framing, or deceptive request routing).
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 400,
  "name": "Bad Request.",
  "message": "Your request is invalid."
}
```

**Response 401:**
### 401 Unauthorized (Client Error) Authentication is required and has failed or has not yet been provided.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 401,
  "name": "Unauthorized.",
  "message": "Your request was made with invalid credentials."
}
```

**Response 403:**
### 403 Forbidden (Client Error) Access to the requested resource is forbidden. The server understood the request, but will not fulfill it.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 403,
  "name": "Forbidden.",
  "message": "Login Required."
}
```

**Response 404:**
### 404 Not Found (Client Error) The requested resource could not be found but may be available in the future.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 404,
  "name": "Not Found.",
  "message": "Item not found."
}
```

**Response 405:**
### 405 Method Not Allowed (Client Error) A request method is not supported for the requested resource. For example, a GET request on a form that requires data to be presented via POST.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 405,
  "name": "Method not allowed.",
  "message": "Method Not Allowed. This url can only handle the following request methods: GET.\n"
}
```

**Response 415:**
### 415 Unsupported Media Type (Client Error) The request entity has a media type which the server or resource does not support. For example, the client set request data as `application/xml`, but the server requires that request data use a different format.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 415,
  "name": "Unsupported Media Type.",
  "message": "None of your requested content types is supported."
}
```

**Response 429:**
### 429 Too Many Requests (Client Error) The user has sent too many requests in a given amount of time.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 429,
  "name": "Too Many Requests.",
  "message": "Rate limit exceeded."
}
```

**Response 500:**
### 500 Internal Server Error (Server Error) A generic error message, given when an unexpected condition was encountered and no more specific message is suitable.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 500,
  "name": "Internal server error.",
  "message": "Failed to create the object for unknown reason."
}
```

### /job-categories

### GET `/v1/job-categories`

List all JobCategories matching query criteria, if provided,
otherwise list all JobCategories.

*Traits:* tra.jobCategory-fieldable, tra.jobCategory-sortable, tra.jobCategory-filtrable, tra.formatable

**Query Parameters:**

- `page` (integer, optional) (default: `1`) — Used to send a page number to be displayed. Example: `2`
- `per-page` (integer, optional) (default: `10`) — Used to send a number of items displayed per page (min `1`, max `50`). Example: `20`
- `fields` (string, optional) (default: `If not passed, will be displayed all available.`) Enum: `id`, `name` — Used to send a list of fields to be displayed. Accepted value is comma-separated string. Example: `id`
- `expand` (string, optional) (default: `If not passed, will be displayed nothing.`) — Used to send a list of extra-fields to be displayed. Accepted value is comma-separated string.
- `sort` (string, optional) (default: `id`) Enum: `id`, `name` — Used to sort the results by given fields. Use minus `-` before field name to sort DESC. Accepted value is comma-separated string. Example: `-id,name`
- `format` (string, optional) (default: `json`) Enum: `json`, `xml` — Used to send a format of data of the response. Do not use together with the `Accept` header.
- `access_token` (string, optional) — Used to send a valid OAuth 2 access token. Do not use together with the `Authorization` header. Example: `eyJz93a...k4laUWw`

**Response 200:**
### 200 OK (Success) Standard response for successful HTTP requests.
- Type: `object`

- `items` (array, **required**) — Collection envelope.
- `_expandable` (array, **required**) — The extra-field's list that are not expanded and can be expanded into objects.
- `_meta` (object, **required**) — Meta information.
  - `totalCount` (integer, optional) — Total number of data items.
  - `pageCount` (integer, optional) — Total number of pages of data.
  - `currentPage` (integer, optional) — The current page number (1-based).
  - `perPage` (integer, optional) — The number of data items in each page.

Example:
```json
{
  "items": [
    {
      "id": 490,
      "name": "Job Category for Testing"
    }
  ],
  "_expandable": [],
  "_meta": {
    "totalCount": 50,
    "pageCount": 5,
    "currentPage": 1,
    "perPage": 10
  }
}
```

**Response 400:**
### 400 Bad Request (Client Error) The server cannot or will not process the request due to an apparent client error (e.g., malformed request syntax, size too large, invalid request message framing, or deceptive request routing).
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 400,
  "name": "Bad Request.",
  "message": "Your request is invalid."
}
```

**Response 401:**
### 401 Unauthorized (Client Error) Authentication is required and has failed or has not yet been provided.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 401,
  "name": "Unauthorized.",
  "message": "Your request was made with invalid credentials."
}
```

**Response 403:**
### 403 Forbidden (Client Error) Access to the requested resource is forbidden. The server understood the request, but will not fulfill it.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 403,
  "name": "Forbidden.",
  "message": "Login Required."
}
```

**Response 405:**
### 405 Method Not Allowed (Client Error) A request method is not supported for the requested resource. For example, a GET request on a form that requires data to be presented via POST.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 405,
  "name": "Method not allowed.",
  "message": "Method Not Allowed. This url can only handle the following request methods: GET.\n"
}
```

**Response 415:**
### 415 Unsupported Media Type (Client Error) The request entity has a media type which the server or resource does not support. For example, the client set request data as `application/xml`, but the server requires that request data use a different format.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 415,
  "name": "Unsupported Media Type.",
  "message": "None of your requested content types is supported."
}
```

**Response 429:**
### 429 Too Many Requests (Client Error) The user has sent too many requests in a given amount of time.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 429,
  "name": "Too Many Requests.",
  "message": "Rate limit exceeded."
}
```

**Response 500:**
### 500 Internal Server Error (Server Error) A generic error message, given when an unexpected condition was encountered and no more specific message is suitable.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 500,
  "name": "Internal server error.",
  "message": "Failed to create the object for unknown reason."
}
```

### GET `/v1/job-categories/{job-category-id}`

Get a JobCategory by identifier.

*Traits:* tra.jobCategory-fieldable, tra.formatable

**URI Parameters:**

- `job-category-id` (integer, **required**) — Used to send an identifier of the JobCategory to be used.

**Query Parameters:**

- `fields` (string, optional) (default: `If not passed, will be displayed all available.`) Enum: `id`, `name` — Used to send a list of fields to be displayed. Accepted value is comma-separated string. Example: `id`
- `expand` (string, optional) (default: `If not passed, will be displayed nothing.`) — Used to send a list of extra-fields to be displayed. Accepted value is comma-separated string.
- `format` (string, optional) (default: `json`) Enum: `json`, `xml` — Used to send a format of data of the response. Do not use together with the `Accept` header.
- `access_token` (string, optional) — Used to send a valid OAuth 2 access token. Do not use together with the `Authorization` header. Example: `eyJz93a...k4laUWw`

**Response 200:**
### 200 OK (Success) Standard response for successful HTTP requests.
- Type: `object`

- `id` (integer, optional) — The job category's identifier.
- `name` (string, optional) — The job category's name.
- `_expandable` (array, **required**) — The extra-field's list that are not expanded and can be expanded into objects.

Example:
```json
{
  "id": 490,
  "name": "Job Category for Testing",
  "_expandable": []
}
```

**Response 400:**
### 400 Bad Request (Client Error) The server cannot or will not process the request due to an apparent client error (e.g., malformed request syntax, size too large, invalid request message framing, or deceptive request routing).
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 400,
  "name": "Bad Request.",
  "message": "Your request is invalid."
}
```

**Response 401:**
### 401 Unauthorized (Client Error) Authentication is required and has failed or has not yet been provided.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 401,
  "name": "Unauthorized.",
  "message": "Your request was made with invalid credentials."
}
```

**Response 403:**
### 403 Forbidden (Client Error) Access to the requested resource is forbidden. The server understood the request, but will not fulfill it.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 403,
  "name": "Forbidden.",
  "message": "Login Required."
}
```

**Response 404:**
### 404 Not Found (Client Error) The requested resource could not be found but may be available in the future.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 404,
  "name": "Not Found.",
  "message": "Item not found."
}
```

**Response 405:**
### 405 Method Not Allowed (Client Error) A request method is not supported for the requested resource. For example, a GET request on a form that requires data to be presented via POST.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 405,
  "name": "Method not allowed.",
  "message": "Method Not Allowed. This url can only handle the following request methods: GET.\n"
}
```

**Response 415:**
### 415 Unsupported Media Type (Client Error) The request entity has a media type which the server or resource does not support. For example, the client set request data as `application/xml`, but the server requires that request data use a different format.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 415,
  "name": "Unsupported Media Type.",
  "message": "None of your requested content types is supported."
}
```

**Response 429:**
### 429 Too Many Requests (Client Error) The user has sent too many requests in a given amount of time.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 429,
  "name": "Too Many Requests.",
  "message": "Rate limit exceeded."
}
```

**Response 500:**
### 500 Internal Server Error (Server Error) A generic error message, given when an unexpected condition was encountered and no more specific message is suitable.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 500,
  "name": "Internal server error.",
  "message": "Failed to create the object for unknown reason."
}
```

### /job-statuses

### GET `/v1/job-statuses`

List all JobStatuses matching query criteria, if provided,
otherwise list all JobStatuses.

*Traits:* tra.jobStatus-fieldable, tra.jobStatus-sortable, tra.jobStatus-filtrable, tra.formatable

**Query Parameters:**

- `page` (integer, optional) (default: `1`) — Used to send a page number to be displayed. Example: `2`
- `per-page` (integer, optional) (default: `10`) — Used to send a number of items displayed per page (min `1`, max `50`). Example: `20`
- `fields` (string, optional) (default: `If not passed, will be displayed all available.`) Enum: `id`, `code`, `name`, `is_custom`, `category` — Used to send a list of fields to be displayed. Accepted value is comma-separated string. Example: `id,code,is_custom`
- `expand` (string, optional) (default: `If not passed, will be displayed nothing.`) — Used to send a list of extra-fields to be displayed. Accepted value is comma-separated string.
- `sort` (string, optional) (default: `id`) Enum: `id`, `code`, `name`, `is_custom`, `category` — Used to sort the results by given fields. Use minus `-` before field name to sort DESC. Accepted value is comma-separated string. Example: `-id,code`
- `format` (string, optional) (default: `json`) Enum: `json`, `xml` — Used to send a format of data of the response. Do not use together with the `Accept` header.
- `access_token` (string, optional) — Used to send a valid OAuth 2 access token. Do not use together with the `Authorization` header. Example: `eyJz93a...k4laUWw`

**Response 200:**
### 200 OK (Success) Standard response for successful HTTP requests.
- Type: `object`

- `items` (array, **required**) — Collection envelope.
- `_expandable` (array, **required**) — The extra-field's list that are not expanded and can be expanded into objects.
- `_meta` (object, **required**) — Meta information.
  - `totalCount` (integer, optional) — Total number of data items.
  - `pageCount` (integer, optional) — Total number of pages of data.
  - `currentPage` (integer, optional) — The current page number (1-based).
  - `perPage` (integer, optional) — The number of data items in each page.

Example:
```json
{
  "items": [
    {
      "id": 1018351032,
      "code": "06_ONS",
      "name": "On Site",
      "is_custom": true,
      "category": "OPEN_ACTIVE"
    }
  ],
  "_expandable": [],
  "_meta": {
    "totalCount": 50,
    "pageCount": 5,
    "currentPage": 1,
    "perPage": 10
  }
}
```

**Response 400:**
### 400 Bad Request (Client Error) The server cannot or will not process the request due to an apparent client error (e.g., malformed request syntax, size too large, invalid request message framing, or deceptive request routing).
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 400,
  "name": "Bad Request.",
  "message": "Your request is invalid."
}
```

**Response 401:**
### 401 Unauthorized (Client Error) Authentication is required and has failed or has not yet been provided.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 401,
  "name": "Unauthorized.",
  "message": "Your request was made with invalid credentials."
}
```

**Response 403:**
### 403 Forbidden (Client Error) Access to the requested resource is forbidden. The server understood the request, but will not fulfill it.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 403,
  "name": "Forbidden.",
  "message": "Login Required."
}
```

**Response 405:**
### 405 Method Not Allowed (Client Error) A request method is not supported for the requested resource. For example, a GET request on a form that requires data to be presented via POST.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 405,
  "name": "Method not allowed.",
  "message": "Method Not Allowed. This url can only handle the following request methods: GET.\n"
}
```

**Response 415:**
### 415 Unsupported Media Type (Client Error) The request entity has a media type which the server or resource does not support. For example, the client set request data as `application/xml`, but the server requires that request data use a different format.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 415,
  "name": "Unsupported Media Type.",
  "message": "None of your requested content types is supported."
}
```

**Response 429:**
### 429 Too Many Requests (Client Error) The user has sent too many requests in a given amount of time.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 429,
  "name": "Too Many Requests.",
  "message": "Rate limit exceeded."
}
```

**Response 500:**
### 500 Internal Server Error (Server Error) A generic error message, given when an unexpected condition was encountered and no more specific message is suitable.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 500,
  "name": "Internal server error.",
  "message": "Failed to create the object for unknown reason."
}
```

### GET `/v1/job-statuses/{job-status-id}`

Get a JobStatus by identifier.

*Traits:* tra.jobStatus-fieldable, tra.formatable

**URI Parameters:**

- `job-status-id` (integer, **required**) — Used to send an identifier of the JobStatus to be used.

**Query Parameters:**

- `fields` (string, optional) (default: `If not passed, will be displayed all available.`) Enum: `id`, `code`, `name`, `is_custom`, `category` — Used to send a list of fields to be displayed. Accepted value is comma-separated string. Example: `id,code,is_custom`
- `expand` (string, optional) (default: `If not passed, will be displayed nothing.`) — Used to send a list of extra-fields to be displayed. Accepted value is comma-separated string.
- `format` (string, optional) (default: `json`) Enum: `json`, `xml` — Used to send a format of data of the response. Do not use together with the `Accept` header.
- `access_token` (string, optional) — Used to send a valid OAuth 2 access token. Do not use together with the `Authorization` header. Example: `eyJz93a...k4laUWw`

**Response 200:**
### 200 OK (Success) Standard response for successful HTTP requests.
- Type: `object`

- `id` (integer, optional) — The job statuse's identifier.
- `code` (string, optional) — The job statuse's code.
- `name` (string, optional) — The job statuse's name.
- `is_custom` (string, optional) — The job statuse's is custom flag.
- `category` (string, optional) — The `header` of attached category to the status (Note: `header` - [string] the category's fields concatenated by pattern `{code}`).
- `_expandable` (array, **required**) — The extra-field's list that are not expanded and can be expanded into objects.

Example:
```json
{
  "id": 1018351032,
  "code": "06_ONS",
  "name": "On Site",
  "is_custom": true,
  "category": "OPEN_ACTIVE",
  "_expandable": []
}
```

**Response 400:**
### 400 Bad Request (Client Error) The server cannot or will not process the request due to an apparent client error (e.g., malformed request syntax, size too large, invalid request message framing, or deceptive request routing).
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 400,
  "name": "Bad Request.",
  "message": "Your request is invalid."
}
```

**Response 401:**
### 401 Unauthorized (Client Error) Authentication is required and has failed or has not yet been provided.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 401,
  "name": "Unauthorized.",
  "message": "Your request was made with invalid credentials."
}
```

**Response 403:**
### 403 Forbidden (Client Error) Access to the requested resource is forbidden. The server understood the request, but will not fulfill it.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 403,
  "name": "Forbidden.",
  "message": "Login Required."
}
```

**Response 404:**
### 404 Not Found (Client Error) The requested resource could not be found but may be available in the future.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 404,
  "name": "Not Found.",
  "message": "Item not found."
}
```

**Response 405:**
### 405 Method Not Allowed (Client Error) A request method is not supported for the requested resource. For example, a GET request on a form that requires data to be presented via POST.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 405,
  "name": "Method not allowed.",
  "message": "Method Not Allowed. This url can only handle the following request methods: GET.\n"
}
```

**Response 415:**
### 415 Unsupported Media Type (Client Error) The request entity has a media type which the server or resource does not support. For example, the client set request data as `application/xml`, but the server requires that request data use a different format.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 415,
  "name": "Unsupported Media Type.",
  "message": "None of your requested content types is supported."
}
```

**Response 429:**
### 429 Too Many Requests (Client Error) The user has sent too many requests in a given amount of time.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 429,
  "name": "Too Many Requests.",
  "message": "Rate limit exceeded."
}
```

**Response 500:**
### 500 Internal Server Error (Server Error) A generic error message, given when an unexpected condition was encountered and no more specific message is suitable.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 500,
  "name": "Internal server error.",
  "message": "Failed to create the object for unknown reason."
}
```

### /estimates

### POST `/v1/estimates`

Create a new Estimate.

*Traits:* tra.estimate-fieldable, tra.formatable

**Query Parameters:**

- `fields` (string, optional) (default: `If not passed, will be displayed all available.`) Enum: `id`, `number`, `description`, `tech_notes`, `payment_status`, `taxes_fees_total`, `total`, `due_total`, `cost_total`, `duration`, `time_frame_promised_start`, `time_frame_promised_end`, `start_date`, `created_at`, `updated_at`, `customer_id`, `customer_name`, `parent_customer`, `status`, `sub_status`, `contact_first_name`, `contact_last_name`, `street_1`, `street_2`, `city`, `state_prov`, `postal_code`, `location_name`, `is_gated`, `gate_instructions`, `category`, `source`, `payment_type`, `customer_payment_terms`, `project`, `phase`, `po_number`, `contract`, `note_to_customer`, `opportunity_rating`, `opportunity_owner` — Used to send a list of fields to be displayed. Accepted value is comma-separated string. Example: `id,tech_notes`
- `expand` (string, optional) (default: `If not passed, will be displayed nothing.`) Enum: `agents`, `custom_fields`, `pictures`, `documents`, `equipment`, `equipment.custom_fields`, `techs_assigned`, `tasks`, `notes`, `products`, `services`, `other_charges`, `payments`, `signatures`, `printable_work_order`, `tags` — Used to send a list of extra-fields to be displayed. Accepted value is comma-separated string. Example: `agents,printable_work_order`
- `format` (string, optional) (default: `json`) Enum: `json`, `xml` — Used to send a format of data of the response. Do not use together with the `Accept` header.
- `access_token` (string, optional) — Used to send a valid OAuth 2 access token. Do not use together with the `Authorization` header. Example: `eyJz93a...k4laUWw`

**Request Body** (`0`):
- Type: `object`

- `description` (string, optional) — Used to send the estimate's description that will be set.
- `tech_notes` (string, optional) — Used to send the estimate's tech notes that will be set.
- `duration` (integer, optional) (default: `3600`) — Used to send the estimate's duration (in seconds) that will be set.
- `time_frame_promised_start` (string, optional) — Used to send the estimate's time frame promised start that will be set.
- `time_frame_promised_end` (string, optional) — Used to send the estimate's time frame promised end that will be set.
- `start_date` (datetime, optional) — Used to send the estimate's start date that will be set.
- `created_at` (datetime, optional) (default: `If not passed, it takes the value as current date and time.`) — Used to send the estimate's created date that will be set.
- `customer_name` (string, **required**) — Used to send a customer's `id` or `header` that will be attached to the estimate (Note: `id` - [integer] the customer's identifier, `header` - [string] the customer's fields concatenated by pattern `{customer_name}`).
- `status` (string, optional) (default: `If not passed, it takes the default status for estimates.`) — Used to send a status'es `id` or `header` that will be attached to the estimate (Note: `id` - [integer] the status'es identifier, `header` - [string] the status'es fields concatenated by pattern `{name}`).
- `contact_first_name` (string, optional) (default: `If not passed, it takes the first name from primary contact of the customer (if exists), otherwise a primary contact will be created for the customer.`) — Used to send the estimate's contact first name that will be set. If a contact with the passed name and surname already exists, then a new contact will not be created, but the existing one will be attached.
- `contact_last_name` (string, optional) (default: `If not passed, it takes the last name from primary contact of the customer (if exists), otherwise a primary contact will be created for the customer.`) — Used to send the estimate's contact last name that will be set. If a contact with the passed name and surname already exists, then a new contact will not be created, but the existing one will be attached.
- `street_1` (string, optional) (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) — Used to send the estimate's location street 1 that will be set.
- `street_2` (string, optional) (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) — Used to send the estimate's location street 2 that will be set.
- `city` (string, optional) (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) — Used to send the estimate's location city that will be set.
- `state_prov` (string, optional) (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) — Used to send the estimate's location state prov that will be set.
- `postal_code` (string, optional) (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) — Used to send the estimate's location postal code that will be set.
- `location_name` (string, optional) (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) — Used to send the estimate's location name that will be set.
- `is_gated` (boolean, optional) (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) — Used to send the estimate's location is gated flag that will be set.
- `gate_instructions` (string, optional) (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) — Used to send the estimate's location gate instructions that will be set.
- `category` (string, optional) — Used to send a category's `id` or `header` that will be attached to the estimate (Note: `id` - [integer] the category's identifier, `header` - [string] the category's fields concatenated by pattern `{category}`). Optionally required (configurable into the company preferences).
- `source` (string, optional) (default: `If not passed, it takes the value from the customer.`) — Used to send a source's `id` or `header` that will be attached to the estimate (Note: `id` - [integer] the source's identifier, `header` - [string] the source's fields concatenated by pattern `{short_name}`).
- `project` (string, optional) — Used to send a project's `id` or `header` that will be attached to the estimate (Note: `id` - [integer] the project's identifier, `header` - [string] the project's fields concatenated by pattern `{name}`).
- `phase` (string, optional) — Used to send a phase's `id` or `header` that will be attached to the estimate (Note: `id` - [integer] the phase's identifier, `header` - [string] the phase's fields concatenated by pattern `{name}`).
- `po_number` (string, optional) — Used to send the estimate's po number that will be set.
- `contract` (string, optional) (default: `If not passed, it takes the value from the customer.`) — Used to send a contract's `id` or `header` that will be attached to the estimate (Note: `id` - [integer] the contract's identifier, `header` - [string] the contract's fields concatenated by pattern `{contract_title}`).
- `note_to_customer` (string, optional) (default: `If not passed, it takes the value from the company preferences.`) — Used to send the estimate's note to customer that will be set.
- `opportunity_rating` (integer, optional) — Used to send the estimate's opportunity rating that will be set.
- `opportunity_owner` (string, optional) (default: `If not passed, it takes the value from the authenticated user.`) — Used to send an opportunity owner's `id` or `header` that will be attached to the estimate (Note: `id` - [integer] the opportunity owner's identifier, `header` - [string] the opportunity owner's fields concatenated by pattern `{first_name} {last_name}` with space as separator).
- `custom_fields` (array, optional) (default: `If some custom field (configured into the custom fields settings) not passed, it creates the new one with its default value.`) — Used to send the estimate's custom fields list that will be set.
- `equipment` (array, optional) (default: `array`) — Used to send the estimate's equipments list that will be set.
- `techs_assigned` (array, optional) (default: `array`) — Used to send the estimate's techs assigned list that will be set.
- `tasks` (array, optional) (default: `array`) — Used to send the estimate's tasks list that will be set.
- `notes` (array, optional) (default: `array`) — Used to send the estimate's notes list that will be set.
- `products` (array, optional) (default: `array`) — Used to send the estimate's products list that will be set.
- `services` (array, optional) (default: `array`) — Used to send the estimate's services list that will be set.
- `other_charges` (array, optional) (default: `If not passed, it creates all entries with `auto added` option enabled. Also it creates all not passed other charges declared into `products` and `services`.`) — Used to send the estimate's other charges list that will be set.
- `tags` (array, optional) (default: `array`) — Used to send the estimate's tags list that will be set.

**Response 201:**
### 201 Created (Success) The request has been fulfilled, resulting in the creation of a new resource.
- Type: `object`

- `id` (integer, optional) — The estimate's identifier.
- `number` (string, optional) — The estimate's number.
- `description` (string, optional) — The estimate's description.
- `tech_notes` (string, optional) — The estimate's tech notes.
- `customer_payment_terms` (string, optional) — The estimate's customer payment terms.
- `payment_status` (string, optional) — The estimate's payment status.
- `taxes_fees_total` (number, optional) — The estimate's taxes and fees total.
- `total` (number, optional) — The estimate's total.
- `due_total` (number, optional) — The estimate's due total.
- `cost_total` (number, optional) — The estimate's cost total.
- `duration` (integer, optional) — The estimate's duration (in seconds).
- `time_frame_promised_start` (string, optional) — The estimate's time frame promised start.
- `time_frame_promised_end` (string, optional) — The estimate's time frame promised end.
- `start_date` (datetime, optional) — The estimate's start date.
- `created_at` (datetime, optional) — The estimate's created date.
- `updated_at` (datetime, optional) — The estimate's updated date.
- `customer_id` (integer, optional) — The `id` of attached customer to the estimate (Note: `id` - [integer] the customer's identifier).
- `customer_name` (string, optional) — The `header` of attached customer to the estimate (Note: `header` - [string] the customer's fields concatenated by pattern `{customer_name}`).
- `parent_customer` (string, optional) — The `header` of attached parent customer to the estimate (Note: `header` - [string] the parent customer's fields concatenated by pattern `{customer_name}`).
- `status` (string, optional) — The `header` of attached status to the estimate (Note: `header` - [string] the status'es fields concatenated by pattern `{name}`).
- `sub_status` (string, optional) — The `header` of attached sub status to the estimate (Note: `header` - [string] the sub status's fields concatenated by pattern `{name}`).
- `contact_first_name` (string, optional) — The estimate's contact first name.
- `contact_last_name` (string, optional) — The estimate's contact last name.
- `street_1` (string, optional) — The estimate's location street 1.
- `street_2` (string, optional) — The estimate's location street 2.
- `city` (string, optional) — The estimate's location city.
- `state_prov` (string, optional) — The estimate's location state prov.
- `postal_code` (string, optional) — The estimate's location postal code.
- `location_name` (string, optional) — The estimate's location name.
- `is_gated` (boolean, optional) — The estimate's location is gated flag.
- `gate_instructions` (string, optional) — The estimate's location gate instructions.
- `category` (string, optional) — The `header` of attached category to the estimate (Note: `header` - [string] the category's fields concatenated by pattern `{category}`).
- `source` (string, optional) — The `header` of attached source to the estimate (Note: `header` - [string] the source's fields concatenated by pattern `{short_name}`).
- `payment_type` (string, optional) — The `header` of attached payment type to the estimate (Note: `header` - [string] the payment type's fields concatenated by pattern `{short_name}`).
- `project` (string, optional) — The `header` of attached project to the estimate (Note: `header` - [string] the project's fields concatenated by pattern `{name}`).
- `phase` (string, optional) — The `header` of attached phase to the estimate (Note: `header` - [string] the phase's fields concatenated by pattern `{name}`).
- `po_number` (string, optional) — The estimate's po number.
- `contract` (string, optional) — The `header` of attached contract to the estimate (Note: `header` - [string] the contract's fields concatenated by pattern `{contract_title}`).
- `note_to_customer` (string, optional) — The estimate's note to customer.
- `opportunity_rating` (integer, optional) — The estimate's opportunity rating.
- `opportunity_owner` (string, optional) — The `header` of attached opportunity owner to the estimate (Note: `header` - [string] the opportunity owner's fields concatenated by pattern `{first_name} {last_name}` with space as separator).
- `agents` (array, optional) — The estimate's agents list.
- `custom_fields` (array, optional) — The estimate's custom fields list.
- `pictures` (array, optional) — The estimate's pictures list.
- `documents` (array, optional) — The estimate's documents list.
- `equipment` (array, optional) — The estimate's equipments list.
- `techs_assigned` (array, optional) — The estimate's techs assigned list.
- `tasks` (array, optional) — The estimate's tasks list.
- `notes` (array, optional) — The estimate's notes list.
- `products` (array, optional) — The estimate's products list.
- `services` (array, optional) — The estimate's services list.
- `other_charges` (array, optional) — The estimate's other charges list.
- `payments` (array, optional) — The estimate's payments list.
- `signatures` (array, optional) — The estimate's signatures list.
- `printable_work_order` (array, optional) — The estimate's printable work order list.
- `tags` (array, optional) — The estimate's tags list.
- `_expandable` (array, **required**) — The extra-field's list that are not expanded and can be expanded into objects.

Example:
```json
{
  "id": 13,
  "number": "1152157",
  "description": "This is a test",
  "tech_notes": "You guys know what to do.",
  "customer_payment_terms": "COD",
  "payment_status": "Unpaid",
  "taxes_fees_total": 193.25,
  "total": 193,
  "due_total": 193,
  "cost_total": 0,
  "duration": 3600,
  "time_frame_promised_start": "14:10",
  "time_frame_promised_end": "14:10",
  "start_date": "2015-01-08",
  "created_at": "2014-09-08T20:42:04+00:00",
  "updated_at": "2016-01-07T17:20:36+00:00",
  "customer_id": 11,
  "customer_name": "Max Paltsev",
  "parent_customer": "Jerry Wheeler",
  "status": "Cancelled",
  "sub_status": "job1",
  "contact_first_name": "Sam",
  "contact_last_name": "Smith",
  "street_1": "1904 Industrial Blvd",
  "street_2": "103",
  "city": "Colleyville",
  "state_prov": "Texas",
  "postal_code": "76034",
  "location_name": "Office",
  "is_gated": false,
  "gate_instructions": null,
  "category": "Quick Home Energy Check-ups",
  "source": "Yellow Pages",
  "payment_type": "Direct Bill",
  "project": "reshma",
  "phase": "Closeup",
  "po_number": "86305",
  "contract": "Retail Service Contract",
  "note_to_customer": "Sample Note To Customer.",
  "opportunity_rating": 4,
  "opportunity_owner": "John Theowner",
  "agents": [
    {
      "id": 31,
      "first_name": "Justin",
      "last_name": "Wormell"
    },
    {
      "id": 32,
      "first_name": "John",
      "last_name": "Theowner"
    }
  ],
  "custom_fields": [
    {
      "name": "Text",
      "value": "Example text value",
      "type": "text",
      "group": "Default",
      "created_at": "2018-10-11T11:52:33+00:00",
      "updated_at": "2018-10-11T11:52:33+00:00",
      "is_required": true
    }
  ],
  "pictures": [
    {
      "name": "1442951633_images.jpeg",
      "file_location": "1442951633_images.jpeg",
      "doc_type": "IMG",
      "comment": null,
      "sort": 2,
      "is_private": false,
      "created_at": "2015-09-22T19:53:53+00:00",
      "updated_at": "2015-09-22T19:53:53+00:00",
      "customer_doc_id": 992
    }
  ],
  "documents": [
    {
      "name": "test1John.pdf",
      "file_location": "1421408539_test1John.pdf",
      "doc_type": "DOC",
      "comment": null,
      "sort": 1,
      "is_private": false,
      "created_at": "2015-01-16T11:42:19+00:00",
      "updated_at": "2018-08-21T08:21:14+00:00",
      "customer_doc_id": 998
    }
  ],
  "equipment": [
    {
      "id": 12,
      "type": "Test Equipment",
      "make": "New Test Manufacturer",
      "model": "TST1231MOD",
      "sku": "SK15432",
      "serial_number": "1231#SRN",
      "location": "Test Location",
      "notes": "Test notes for the Test Equipment",
      "extended_warranty_provider": "Test War Provider",
      "is_extended_warranty": false,
      "extended_warranty_date": "2015-02-17",
      "warranty_date": "2015-01-16",
      "install_date": "2014-12-15",
      "created_at": "2015-01-16T11:31:49+00:00",
      "updated_at": "2015-01-16T11:31:49+00:00",
      "customer_id": 87,
      "customer": "John Theowner",
      "customer_location": "Office",
      "custom_fields": [
        {
          "name": "Text",
          "value": "Example text value",
          "type": "text",
          "group": "Default",
          "created_at": "2018-10-11T11:52:33+00:00",
          "updated_at": "2018-10-11T11:52:33+00:00",
          "is_required": true
        }
      ]
    }
  ],
  "techs_assigned": [
    {
      "id": 31,
      "first_name": "Justin",
      "last_name": "Wormell"
    },
    {
      "id": 32,
      "first_name": "John",
      "last_name": "Theowner"
    }
  ],
  "tasks": [
    {
      "type": "Misc",
      "description": "x",
      "start_time": null,
      "start_date": null,
      "end_date": null,
      "is_completed": false,
      "created_at": "2017-03-20T10:48:38+00:00",
      "updated_at": "2017-03-20T10:48:38+00:00"
    }
  ],
  "notes": [
    {
      "notes": "SHOULD BE DELIVERED TO US 6/1/15 AND RICHARD NEEDS TO PAINT",
      "created_at": "2015-05-27T16:32:06+00:00",
      "updated_at": "2015-05-27T16:32:06+00:00"
    }
  ],
  "products": [
    {
      "name": "1755LFB",
      "description": "Finishing Trim Kit - 1\" - Black\r\nModel: \r\nSKU: \r\nType: \r\nPart Number: ",
      "multiplier": 3,
      "rate": 459,
      "total": 1377,
      "cost": 0,
      "actual_cost": 0,
      "item_index": 0,
      "parent_index": 0,
      "created_at": "2015-08-20T09:08:36+00:00",
      "updated_at": "2015-11-19T20:38:07+00:00",
      "is_show_rate_items": true,
      "tax": "City Tax",
      "product": "1755LFB",
      "product_list_id": 45302,
      "warehouse_id": 200,
      "pattern_row_id": null,
      "qbo_class_id": null,
      "qbd_class_id": null
    }
  ],
  "services": [
    {
      "name": "Service Call Fee",
      "description": null,
      "multiplier": 1,
      "rate": 33.15,
      "total": 121,
      "cost": 121,
      "actual_cost": 121,
      "item_index": 3,
      "parent_index": 0,
      "created_at": "2015-08-20T09:08:36+00:00",
      "updated_at": "2015-11-19T20:38:07+00:00",
      "is_show_rate_items": true,
      "tax": "City Tax",
      "service": "Nabeeel",
      "service_list_id": 45302,
      "service_rate_id": 200,
      "pattern_row_id": null,
      "qbo_class_id": null,
      "qbd_class_id": null
    }
  ],
  "other_charges": [
    {
      "name": "fee1",
      "rate": 5.15,
      "total": 14.3,
      "charge_index": 1,
      "parent_index": 1,
      "is_percentage": true,
      "is_discount": false,
      "created_at": "2015-08-20T09:08:52+00:00",
      "updated_at": "2015-11-19T20:38:07+00:00",
      "other_charge": "fee1",
      "applies_to": null,
      "service_list_id": null,
      "other_charge_id": 248,
      "pattern_row_id": null,
      "qbo_class_id": null,
      "qbd_class_id": null
    }
  ],
  "payments": [
    {
      "transaction_type": "AUTH_CAPTURE",
      "transaction_token": "4Tczi4OI12MeoSaC4FG2VPKj1",
      "transaction_id": "257494-0_10",
      "payment_transaction_id": 10,
      "original_transaction_id": 110,
      "apply_to": "JOB",
      "amount": 10.35,
      "memo": null,
      "authorization_code": "755972",
      "bill_to_street_address": "adddad",
      "bill_to_postal_code": "adadadd",
      "bill_to_country": null,
      "reference_number": "1976/1410",
      "is_resync_qbo": false,
      "created_at": "2015-09-25T09:56:57+00:00",
      "updated_at": "2015-09-25T09:56:57+00:00",
      "received_on": "2015-09-25T00:00:00+00:00",
      "qbo_synced_date": "2015-09-25T00:00:00+00:00",
      "qbo_id": 5,
      "qbd_id": "3792-1438659918",
      "customer": "Max Paltsev",
      "type": "Cash",
      "invoice_id": 124,
      "gateway_id": 980190963,
      "receipt_id": "ord-250915-9:56:56"
    }
  ],
  "signatures": [
    {
      "type": "PREWORK",
      "file_name": "https://servicefusion.s3.amazonaws.com/images/sign/139350-2015-08-25-11-35-14.png",
      "created_at": "2015-08-25T11:35:14+00:00",
      "updated_at": "2015-08-25T11:35:14+00:00"
    }
  ],
  "printable_work_order": [
    {
      "name": "Print With Rates",
      "url": "https://servicefusion.com/printJobWithRates?jobId=fF7HY2Dew1E9vw2mm8FHzSOrpDrKnSl-m2WKf0Yg_Kw"
    }
  ],
  "tags": [
    {
      "tag": "Referral",
      "created_at": "2017-03-20T10:48:38+00:00",
      "updated_at": "2017-03-20T10:48:38+00:00"
    }
  ],
  "_expandable": [
    "agents",
    "custom_fields",
    "pictures",
    "documents",
    "equipment",
    "equipment.custom_fields",
    "techs_assigned",
    "tasks",
    "notes",
    "products",
    "services",
    "other_charges",
    "payments",
    "signatures",
    "printable_work_order",
    "tags"
  ]
}
```

**Response 400:**
### 400 Bad Request (Client Error) The server cannot or will not process the request due to an apparent client error (e.g., malformed request syntax, size too large, invalid request message framing, or deceptive request routing).
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 400,
  "name": "Bad Request.",
  "message": "Your request is invalid."
}
```

**Response 401:**
### 401 Unauthorized (Client Error) Authentication is required and has failed or has not yet been provided.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 401,
  "name": "Unauthorized.",
  "message": "Your request was made with invalid credentials."
}
```

**Response 403:**
### 403 Forbidden (Client Error) Access to the requested resource is forbidden. The server understood the request, but will not fulfill it.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 403,
  "name": "Forbidden.",
  "message": "Login Required."
}
```

**Response 405:**
### 405 Method Not Allowed (Client Error) A request method is not supported for the requested resource. For example, a GET request on a form that requires data to be presented via POST.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 405,
  "name": "Method not allowed.",
  "message": "Method Not Allowed. This url can only handle the following request methods: GET.\n"
}
```

**Response 415:**
### 415 Unsupported Media Type (Client Error) The request entity has a media type which the server or resource does not support. For example, the client set request data as `application/xml`, but the server requires that request data use a different format.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 415,
  "name": "Unsupported Media Type.",
  "message": "None of your requested content types is supported."
}
```

**Response 422:**
### 422 Unprocessable Entity (Client Error) The request was well-formed but was unable to be followed due to semantic errors.
- Type: `array`

Example:
```json
[
  {
    "field": "name",
    "message": "Name is too long (maximum is 45 characters)."
  }
]
```

**Response 429:**
### 429 Too Many Requests (Client Error) The user has sent too many requests in a given amount of time.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 429,
  "name": "Too Many Requests.",
  "message": "Rate limit exceeded."
}
```

**Response 500:**
### 500 Internal Server Error (Server Error) A generic error message, given when an unexpected condition was encountered and no more specific message is suitable.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 500,
  "name": "Internal server error.",
  "message": "Failed to create the object for unknown reason."
}
```

### GET `/v1/estimates`

List all Estimates matching query criteria, if provided,
otherwise list all Estimates.

*Traits:* tra.estimate-fieldable, tra.estimate-sortable, tra.estimate-filtrable, tra.formatable

**Query Parameters:**

- `page` (integer, optional) (default: `1`) — Used to send a page number to be displayed. Example: `2`
- `per-page` (integer, optional) (default: `10`) — Used to send a number of items displayed per page (min `1`, max `50`). Example: `20`
- `fields` (string, optional) (default: `If not passed, will be displayed all available.`) Enum: `id`, `number`, `description`, `tech_notes`, `payment_status`, `taxes_fees_total`, `total`, `due_total`, `cost_total`, `duration`, `time_frame_promised_start`, `time_frame_promised_end`, `start_date`, `created_at`, `updated_at`, `customer_id`, `customer_name`, `parent_customer`, `status`, `sub_status`, `contact_first_name`, `contact_last_name`, `street_1`, `street_2`, `city`, `state_prov`, `postal_code`, `location_name`, `is_gated`, `gate_instructions`, `category`, `source`, `payment_type`, `customer_payment_terms`, `project`, `phase`, `po_number`, `contract`, `note_to_customer`, `opportunity_rating`, `opportunity_owner` — Used to send a list of fields to be displayed. Accepted value is comma-separated string. Example: `id,tech_notes`
- `expand` (string, optional) (default: `If not passed, will be displayed nothing.`) Enum: `agents`, `custom_fields`, `pictures`, `documents`, `equipment`, `equipment.custom_fields`, `techs_assigned`, `tasks`, `notes`, `products`, `services`, `other_charges`, `payments`, `signatures`, `printable_work_order`, `tags` — Used to send a list of extra-fields to be displayed. Accepted value is comma-separated string. Example: `agents,printable_work_order`
- `sort` (string, optional) (default: `id`) Enum: `id`, `number`, `po_number`, `description`, `tech_notes`, `duration`, `time_frame_promised_start`, `time_frame_promised_end`, `start_date`, `created_at`, `updated_at`, `customer_id`, `customer_name`, `status`, `sub_status`, `category`, `source`, `payment_type`, `customer_payment_terms`, `contract`, `opportunity_rating` — Used to sort the results by given fields. Use minus `-` before field name to sort DESC. Accepted value is comma-separated string. Example: `number,-start_date`
- `filters[status]` (string, optional) — Used to filter results by given statuses (full match). Accepted value is comma-separated string. Example: `Estimate Closed, Cancelled`
- `filters[number]` (string, optional) — Used to filter results by given number (partial match). Example: `101`
- `filters[po_number]` (string, optional) — Used to filter results by given po number (partial match). Example: `101`
- `filters[customer_name]` (string, optional) — Used to filter results by given customer's name (partial match). Example: `John Walter`
- `filters[parent_customer_name]` (string, optional) — Used to filter results by given parent customer's name (partial match). Example: `John Walter`
- `filters[contact_first_name]` (string, optional) — Used to filter results by given contact's first name (partial match). Example: `John`
- `filters[contact_last_name]` (string, optional) — Used to filter results by given contact's last name (partial match). Example: `Walter`
- `filters[address]` (string, optional) — Used to filter results by given address (partial match). Example: `3210 Midway Ave`
- `filters[city]` (string, optional) — Used to filter results by given city (full match). Example: `Dallas`
- `filters[zip_code]` (integer, optional) — Used to filter results by given zip code (full match). Example: `75242`
- `filters[phone]` (string, optional) — Used to filter results by given phone (partial match). Example: `214-555-1212`
- `filters[email]` (string, optional) — Used to filter results by given email (full match). Example: `john.walter@gmail.com`
- `filters[category]` (string, optional) — Used to filter results by given categories (full match). Accepted value is comma-separated string. Example: `Install, Service Call`
- `filters[source]` (string, optional) — Used to filter results by given sources (full match). Accepted value is comma-separated string. Example: `Google, Yelp`
- `filters[start_date][lte]` (string, optional) — Used to filter results by given `less than or equal` of start date (format: `Y-m-d`). Example: `2002-10-02`
- `filters[start_date][gte]` (string, optional) — Used to filter results by given `greater than or equal` of start date (format: `Y-m-d`). Example: `2002-10-02`
- `filters[end_date][lte]` (string, optional) — Used to filter results by given `less than or equal` of end date (format: `Y-m-d`). Example: `2002-10-02`
- `filters[end_date][gte]` (string, optional) — Used to filter results by given `greater than or equal` of end date (format: `Y-m-d`). Example: `2002-10-02`
- `filters[requested_date][lte]` (string, optional) — Used to filter results by given `less than or equal` of requested date (format `RFC 3339`: `Y-m-d\TH:i:sP`). Example: `2002-10-02T10:00:00-05:00`
- `filters[requested_date][gte]` (string, optional) — Used to filter results by given `greater than or equal` of requested date (format `RFC 3339`: `Y-m-d\TH:i:sP`). Example: `2002-10-02T10:00:00-05:00`
- `format` (string, optional) (default: `json`) Enum: `json`, `xml` — Used to send a format of data of the response. Do not use together with the `Accept` header.
- `access_token` (string, optional) — Used to send a valid OAuth 2 access token. Do not use together with the `Authorization` header. Example: `eyJz93a...k4laUWw`

**Response 200:**
### 200 OK (Success) Standard response for successful HTTP requests.
- Type: `object`

- `items` (array, **required**) — Collection envelope.
- `_expandable` (array, **required**) — The extra-field's list that are not expanded and can be expanded into objects.
- `_meta` (object, **required**) — Meta information.
  - `totalCount` (integer, optional) — Total number of data items.
  - `pageCount` (integer, optional) — Total number of pages of data.
  - `currentPage` (integer, optional) — The current page number (1-based).
  - `perPage` (integer, optional) — The number of data items in each page.

**Response 400:**
### 400 Bad Request (Client Error) The server cannot or will not process the request due to an apparent client error (e.g., malformed request syntax, size too large, invalid request message framing, or deceptive request routing).
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 400,
  "name": "Bad Request.",
  "message": "Your request is invalid."
}
```

**Response 401:**
### 401 Unauthorized (Client Error) Authentication is required and has failed or has not yet been provided.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 401,
  "name": "Unauthorized.",
  "message": "Your request was made with invalid credentials."
}
```

**Response 403:**
### 403 Forbidden (Client Error) Access to the requested resource is forbidden. The server understood the request, but will not fulfill it.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 403,
  "name": "Forbidden.",
  "message": "Login Required."
}
```

**Response 405:**
### 405 Method Not Allowed (Client Error) A request method is not supported for the requested resource. For example, a GET request on a form that requires data to be presented via POST.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 405,
  "name": "Method not allowed.",
  "message": "Method Not Allowed. This url can only handle the following request methods: GET.\n"
}
```

**Response 415:**
### 415 Unsupported Media Type (Client Error) The request entity has a media type which the server or resource does not support. For example, the client set request data as `application/xml`, but the server requires that request data use a different format.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 415,
  "name": "Unsupported Media Type.",
  "message": "None of your requested content types is supported."
}
```

**Response 429:**
### 429 Too Many Requests (Client Error) The user has sent too many requests in a given amount of time.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 429,
  "name": "Too Many Requests.",
  "message": "Rate limit exceeded."
}
```

**Response 500:**
### 500 Internal Server Error (Server Error) A generic error message, given when an unexpected condition was encountered and no more specific message is suitable.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 500,
  "name": "Internal server error.",
  "message": "Failed to create the object for unknown reason."
}
```

### GET `/v1/estimates/{estimate-id}`

Get a Estimate by identifier.

*Traits:* tra.estimate-fieldable, tra.formatable

**URI Parameters:**

- `estimate-id` (integer, **required**) — Used to send an identifier of the Estimate to be used.

**Query Parameters:**

- `fields` (string, optional) (default: `If not passed, will be displayed all available.`) Enum: `id`, `number`, `description`, `tech_notes`, `payment_status`, `taxes_fees_total`, `total`, `due_total`, `cost_total`, `duration`, `time_frame_promised_start`, `time_frame_promised_end`, `start_date`, `created_at`, `updated_at`, `customer_id`, `customer_name`, `parent_customer`, `status`, `sub_status`, `contact_first_name`, `contact_last_name`, `street_1`, `street_2`, `city`, `state_prov`, `postal_code`, `location_name`, `is_gated`, `gate_instructions`, `category`, `source`, `payment_type`, `customer_payment_terms`, `project`, `phase`, `po_number`, `contract`, `note_to_customer`, `opportunity_rating`, `opportunity_owner` — Used to send a list of fields to be displayed. Accepted value is comma-separated string. Example: `id,tech_notes`
- `expand` (string, optional) (default: `If not passed, will be displayed nothing.`) Enum: `agents`, `custom_fields`, `pictures`, `documents`, `equipment`, `equipment.custom_fields`, `techs_assigned`, `tasks`, `notes`, `products`, `services`, `other_charges`, `payments`, `signatures`, `printable_work_order`, `tags` — Used to send a list of extra-fields to be displayed. Accepted value is comma-separated string. Example: `agents,printable_work_order`
- `format` (string, optional) (default: `json`) Enum: `json`, `xml` — Used to send a format of data of the response. Do not use together with the `Accept` header.
- `access_token` (string, optional) — Used to send a valid OAuth 2 access token. Do not use together with the `Authorization` header. Example: `eyJz93a...k4laUWw`

**Response 200:**
### 200 OK (Success) Standard response for successful HTTP requests.
- Type: `object`

- `id` (integer, optional) — The estimate's identifier.
- `number` (string, optional) — The estimate's number.
- `description` (string, optional) — The estimate's description.
- `tech_notes` (string, optional) — The estimate's tech notes.
- `customer_payment_terms` (string, optional) — The estimate's customer payment terms.
- `payment_status` (string, optional) — The estimate's payment status.
- `taxes_fees_total` (number, optional) — The estimate's taxes and fees total.
- `total` (number, optional) — The estimate's total.
- `due_total` (number, optional) — The estimate's due total.
- `cost_total` (number, optional) — The estimate's cost total.
- `duration` (integer, optional) — The estimate's duration (in seconds).
- `time_frame_promised_start` (string, optional) — The estimate's time frame promised start.
- `time_frame_promised_end` (string, optional) — The estimate's time frame promised end.
- `start_date` (datetime, optional) — The estimate's start date.
- `created_at` (datetime, optional) — The estimate's created date.
- `updated_at` (datetime, optional) — The estimate's updated date.
- `customer_id` (integer, optional) — The `id` of attached customer to the estimate (Note: `id` - [integer] the customer's identifier).
- `customer_name` (string, optional) — The `header` of attached customer to the estimate (Note: `header` - [string] the customer's fields concatenated by pattern `{customer_name}`).
- `parent_customer` (string, optional) — The `header` of attached parent customer to the estimate (Note: `header` - [string] the parent customer's fields concatenated by pattern `{customer_name}`).
- `status` (string, optional) — The `header` of attached status to the estimate (Note: `header` - [string] the status'es fields concatenated by pattern `{name}`).
- `sub_status` (string, optional) — The `header` of attached sub status to the estimate (Note: `header` - [string] the sub status's fields concatenated by pattern `{name}`).
- `contact_first_name` (string, optional) — The estimate's contact first name.
- `contact_last_name` (string, optional) — The estimate's contact last name.
- `street_1` (string, optional) — The estimate's location street 1.
- `street_2` (string, optional) — The estimate's location street 2.
- `city` (string, optional) — The estimate's location city.
- `state_prov` (string, optional) — The estimate's location state prov.
- `postal_code` (string, optional) — The estimate's location postal code.
- `location_name` (string, optional) — The estimate's location name.
- `is_gated` (boolean, optional) — The estimate's location is gated flag.
- `gate_instructions` (string, optional) — The estimate's location gate instructions.
- `category` (string, optional) — The `header` of attached category to the estimate (Note: `header` - [string] the category's fields concatenated by pattern `{category}`).
- `source` (string, optional) — The `header` of attached source to the estimate (Note: `header` - [string] the source's fields concatenated by pattern `{short_name}`).
- `payment_type` (string, optional) — The `header` of attached payment type to the estimate (Note: `header` - [string] the payment type's fields concatenated by pattern `{short_name}`).
- `project` (string, optional) — The `header` of attached project to the estimate (Note: `header` - [string] the project's fields concatenated by pattern `{name}`).
- `phase` (string, optional) — The `header` of attached phase to the estimate (Note: `header` - [string] the phase's fields concatenated by pattern `{name}`).
- `po_number` (string, optional) — The estimate's po number.
- `contract` (string, optional) — The `header` of attached contract to the estimate (Note: `header` - [string] the contract's fields concatenated by pattern `{contract_title}`).
- `note_to_customer` (string, optional) — The estimate's note to customer.
- `opportunity_rating` (integer, optional) — The estimate's opportunity rating.
- `opportunity_owner` (string, optional) — The `header` of attached opportunity owner to the estimate (Note: `header` - [string] the opportunity owner's fields concatenated by pattern `{first_name} {last_name}` with space as separator).
- `agents` (array, optional) — The estimate's agents list.
- `custom_fields` (array, optional) — The estimate's custom fields list.
- `pictures` (array, optional) — The estimate's pictures list.
- `documents` (array, optional) — The estimate's documents list.
- `equipment` (array, optional) — The estimate's equipments list.
- `techs_assigned` (array, optional) — The estimate's techs assigned list.
- `tasks` (array, optional) — The estimate's tasks list.
- `notes` (array, optional) — The estimate's notes list.
- `products` (array, optional) — The estimate's products list.
- `services` (array, optional) — The estimate's services list.
- `other_charges` (array, optional) — The estimate's other charges list.
- `payments` (array, optional) — The estimate's payments list.
- `signatures` (array, optional) — The estimate's signatures list.
- `printable_work_order` (array, optional) — The estimate's printable work order list.
- `tags` (array, optional) — The estimate's tags list.
- `_expandable` (array, **required**) — The extra-field's list that are not expanded and can be expanded into objects.

Example:
```json
{
  "id": 13,
  "number": "1152157",
  "description": "This is a test",
  "tech_notes": "You guys know what to do.",
  "customer_payment_terms": "COD",
  "payment_status": "Unpaid",
  "taxes_fees_total": 193.25,
  "total": 193,
  "due_total": 193,
  "cost_total": 0,
  "duration": 3600,
  "time_frame_promised_start": "14:10",
  "time_frame_promised_end": "14:10",
  "start_date": "2015-01-08",
  "created_at": "2014-09-08T20:42:04+00:00",
  "updated_at": "2016-01-07T17:20:36+00:00",
  "customer_id": 11,
  "customer_name": "Max Paltsev",
  "parent_customer": "Jerry Wheeler",
  "status": "Cancelled",
  "sub_status": "job1",
  "contact_first_name": "Sam",
  "contact_last_name": "Smith",
  "street_1": "1904 Industrial Blvd",
  "street_2": "103",
  "city": "Colleyville",
  "state_prov": "Texas",
  "postal_code": "76034",
  "location_name": "Office",
  "is_gated": false,
  "gate_instructions": null,
  "category": "Quick Home Energy Check-ups",
  "source": "Yellow Pages",
  "payment_type": "Direct Bill",
  "project": "reshma",
  "phase": "Closeup",
  "po_number": "86305",
  "contract": "Retail Service Contract",
  "note_to_customer": "Sample Note To Customer.",
  "opportunity_rating": 4,
  "opportunity_owner": "John Theowner",
  "agents": [
    {
      "id": 31,
      "first_name": "Justin",
      "last_name": "Wormell"
    },
    {
      "id": 32,
      "first_name": "John",
      "last_name": "Theowner"
    }
  ],
  "custom_fields": [
    {
      "name": "Text",
      "value": "Example text value",
      "type": "text",
      "group": "Default",
      "created_at": "2018-10-11T11:52:33+00:00",
      "updated_at": "2018-10-11T11:52:33+00:00",
      "is_required": true
    }
  ],
  "pictures": [
    {
      "name": "1442951633_images.jpeg",
      "file_location": "1442951633_images.jpeg",
      "doc_type": "IMG",
      "comment": null,
      "sort": 2,
      "is_private": false,
      "created_at": "2015-09-22T19:53:53+00:00",
      "updated_at": "2015-09-22T19:53:53+00:00",
      "customer_doc_id": 992
    }
  ],
  "documents": [
    {
      "name": "test1John.pdf",
      "file_location": "1421408539_test1John.pdf",
      "doc_type": "DOC",
      "comment": null,
      "sort": 1,
      "is_private": false,
      "created_at": "2015-01-16T11:42:19+00:00",
      "updated_at": "2018-08-21T08:21:14+00:00",
      "customer_doc_id": 998
    }
  ],
  "equipment": [
    {
      "id": 12,
      "type": "Test Equipment",
      "make": "New Test Manufacturer",
      "model": "TST1231MOD",
      "sku": "SK15432",
      "serial_number": "1231#SRN",
      "location": "Test Location",
      "notes": "Test notes for the Test Equipment",
      "extended_warranty_provider": "Test War Provider",
      "is_extended_warranty": false,
      "extended_warranty_date": "2015-02-17",
      "warranty_date": "2015-01-16",
      "install_date": "2014-12-15",
      "created_at": "2015-01-16T11:31:49+00:00",
      "updated_at": "2015-01-16T11:31:49+00:00",
      "customer_id": 87,
      "customer": "John Theowner",
      "customer_location": "Office",
      "custom_fields": [
        {
          "name": "Text",
          "value": "Example text value",
          "type": "text",
          "group": "Default",
          "created_at": "2018-10-11T11:52:33+00:00",
          "updated_at": "2018-10-11T11:52:33+00:00",
          "is_required": true
        }
      ]
    }
  ],
  "techs_assigned": [
    {
      "id": 31,
      "first_name": "Justin",
      "last_name": "Wormell"
    },
    {
      "id": 32,
      "first_name": "John",
      "last_name": "Theowner"
    }
  ],
  "tasks": [
    {
      "type": "Misc",
      "description": "x",
      "start_time": null,
      "start_date": null,
      "end_date": null,
      "is_completed": false,
      "created_at": "2017-03-20T10:48:38+00:00",
      "updated_at": "2017-03-20T10:48:38+00:00"
    }
  ],
  "notes": [
    {
      "notes": "SHOULD BE DELIVERED TO US 6/1/15 AND RICHARD NEEDS TO PAINT",
      "created_at": "2015-05-27T16:32:06+00:00",
      "updated_at": "2015-05-27T16:32:06+00:00"
    }
  ],
  "products": [
    {
      "name": "1755LFB",
      "description": "Finishing Trim Kit - 1\" - Black\r\nModel: \r\nSKU: \r\nType: \r\nPart Number: ",
      "multiplier": 3,
      "rate": 459,
      "total": 1377,
      "cost": 0,
      "actual_cost": 0,
      "item_index": 0,
      "parent_index": 0,
      "created_at": "2015-08-20T09:08:36+00:00",
      "updated_at": "2015-11-19T20:38:07+00:00",
      "is_show_rate_items": true,
      "tax": "City Tax",
      "product": "1755LFB",
      "product_list_id": 45302,
      "warehouse_id": 200,
      "pattern_row_id": null,
      "qbo_class_id": null,
      "qbd_class_id": null
    }
  ],
  "services": [
    {
      "name": "Service Call Fee",
      "description": null,
      "multiplier": 1,
      "rate": 33.15,
      "total": 121,
      "cost": 121,
      "actual_cost": 121,
      "item_index": 3,
      "parent_index": 0,
      "created_at": "2015-08-20T09:08:36+00:00",
      "updated_at": "2015-11-19T20:38:07+00:00",
      "is_show_rate_items": true,
      "tax": "City Tax",
      "service": "Nabeeel",
      "service_list_id": 45302,
      "service_rate_id": 200,
      "pattern_row_id": null,
      "qbo_class_id": null,
      "qbd_class_id": null
    }
  ],
  "other_charges": [
    {
      "name": "fee1",
      "rate": 5.15,
      "total": 14.3,
      "charge_index": 1,
      "parent_index": 1,
      "is_percentage": true,
      "is_discount": false,
      "created_at": "2015-08-20T09:08:52+00:00",
      "updated_at": "2015-11-19T20:38:07+00:00",
      "other_charge": "fee1",
      "applies_to": null,
      "service_list_id": null,
      "other_charge_id": 248,
      "pattern_row_id": null,
      "qbo_class_id": null,
      "qbd_class_id": null
    }
  ],
  "payments": [
    {
      "transaction_type": "AUTH_CAPTURE",
      "transaction_token": "4Tczi4OI12MeoSaC4FG2VPKj1",
      "transaction_id": "257494-0_10",
      "payment_transaction_id": 10,
      "original_transaction_id": 110,
      "apply_to": "JOB",
      "amount": 10.35,
      "memo": null,
      "authorization_code": "755972",
      "bill_to_street_address": "adddad",
      "bill_to_postal_code": "adadadd",
      "bill_to_country": null,
      "reference_number": "1976/1410",
      "is_resync_qbo": false,
      "created_at": "2015-09-25T09:56:57+00:00",
      "updated_at": "2015-09-25T09:56:57+00:00",
      "received_on": "2015-09-25T00:00:00+00:00",
      "qbo_synced_date": "2015-09-25T00:00:00+00:00",
      "qbo_id": 5,
      "qbd_id": "3792-1438659918",
      "customer": "Max Paltsev",
      "type": "Cash",
      "invoice_id": 124,
      "gateway_id": 980190963,
      "receipt_id": "ord-250915-9:56:56"
    }
  ],
  "signatures": [
    {
      "type": "PREWORK",
      "file_name": "https://servicefusion.s3.amazonaws.com/images/sign/139350-2015-08-25-11-35-14.png",
      "created_at": "2015-08-25T11:35:14+00:00",
      "updated_at": "2015-08-25T11:35:14+00:00"
    }
  ],
  "printable_work_order": [
    {
      "name": "Print With Rates",
      "url": "https://servicefusion.com/printJobWithRates?jobId=fF7HY2Dew1E9vw2mm8FHzSOrpDrKnSl-m2WKf0Yg_Kw"
    }
  ],
  "tags": [
    {
      "tag": "Referral",
      "created_at": "2017-03-20T10:48:38+00:00",
      "updated_at": "2017-03-20T10:48:38+00:00"
    }
  ],
  "_expandable": [
    "agents",
    "custom_fields",
    "pictures",
    "documents",
    "equipment",
    "equipment.custom_fields",
    "techs_assigned",
    "tasks",
    "notes",
    "products",
    "services",
    "other_charges",
    "payments",
    "signatures",
    "printable_work_order",
    "tags"
  ]
}
```

**Response 400:**
### 400 Bad Request (Client Error) The server cannot or will not process the request due to an apparent client error (e.g., malformed request syntax, size too large, invalid request message framing, or deceptive request routing).
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 400,
  "name": "Bad Request.",
  "message": "Your request is invalid."
}
```

**Response 401:**
### 401 Unauthorized (Client Error) Authentication is required and has failed or has not yet been provided.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 401,
  "name": "Unauthorized.",
  "message": "Your request was made with invalid credentials."
}
```

**Response 403:**
### 403 Forbidden (Client Error) Access to the requested resource is forbidden. The server understood the request, but will not fulfill it.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 403,
  "name": "Forbidden.",
  "message": "Login Required."
}
```

**Response 404:**
### 404 Not Found (Client Error) The requested resource could not be found but may be available in the future.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 404,
  "name": "Not Found.",
  "message": "Item not found."
}
```

**Response 405:**
### 405 Method Not Allowed (Client Error) A request method is not supported for the requested resource. For example, a GET request on a form that requires data to be presented via POST.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 405,
  "name": "Method not allowed.",
  "message": "Method Not Allowed. This url can only handle the following request methods: GET.\n"
}
```

**Response 415:**
### 415 Unsupported Media Type (Client Error) The request entity has a media type which the server or resource does not support. For example, the client set request data as `application/xml`, but the server requires that request data use a different format.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 415,
  "name": "Unsupported Media Type.",
  "message": "None of your requested content types is supported."
}
```

**Response 429:**
### 429 Too Many Requests (Client Error) The user has sent too many requests in a given amount of time.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 429,
  "name": "Too Many Requests.",
  "message": "Rate limit exceeded."
}
```

**Response 500:**
### 500 Internal Server Error (Server Error) A generic error message, given when an unexpected condition was encountered and no more specific message is suitable.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 500,
  "name": "Internal server error.",
  "message": "Failed to create the object for unknown reason."
}
```

### /invoices

### GET `/v1/invoices`

List all Invoices matching query criteria, if provided,
otherwise list all Invoices.

*Traits:* tra.invoice-fieldable, tra.invoice-sortable, tra.invoice-filtrable, tra.formatable

**Query Parameters:**

- `page` (integer, optional) (default: `1`) — Used to send a page number to be displayed. Example: `2`
- `per-page` (integer, optional) (default: `10`) — Used to send a number of items displayed per page (min `1`, max `50`). Example: `20`
- `fields` (string, optional) (default: `If not passed, will be displayed all available.`) Enum: `id`, `number`, `currency`, `po_number`, `terms`, `customer_message`, `notes`, `pay_online_url`, `qbo_invoice_no`, `qbo_sync_token`, `qbo_synced_date`, `qbo_id`, `qbd_id`, `total`, `is_paid`, `date`, `mail_send_date`, `created_at`, `updated_at`, `customer`, `customer_contact`, `payment_terms`, `bill_to_customer_id`, `bill_to_customer_location_id`, `bill_to_customer_contact_id`, `bill_to_email_id`, `bill_to_phone_id` — Used to send a list of fields to be displayed. Accepted value is comma-separated string. Example: `id,notes`
- `expand` (string, optional) (default: `If not passed, will be displayed nothing.`) — Used to send a list of extra-fields to be displayed. Accepted value is comma-separated string.
- `sort` (string, optional) (default: `id`) Enum: `id`, `number`, `currency`, `po_number`, `terms`, `customer_message`, `notes`, `qbo_invoice_no`, `qbo_sync_token`, `qbo_synced_date`, `qbo_id`, `qbd_id`, `total`, `is_paid`, `date`, `mail_send_date`, `created_at`, `updated_at`, `customer`, `customer_contact`, `payment_terms`, `bill_to_customer_id`, `bill_to_customer_location_id`, `bill_to_customer_contact_id`, `bill_to_email_id`, `bill_to_phone_id` — Used to sort the results by given fields. Use minus `-` before field name to sort DESC. Accepted value is comma-separated string. Example: `created_at,-number`
- `format` (string, optional) (default: `json`) Enum: `json`, `xml` — Used to send a format of data of the response. Do not use together with the `Accept` header.
- `access_token` (string, optional) — Used to send a valid OAuth 2 access token. Do not use together with the `Authorization` header. Example: `eyJz93a...k4laUWw`

**Response 200:**
### 200 OK (Success) Standard response for successful HTTP requests.
- Type: `object`

- `items` (array, **required**) — Collection envelope.
- `_expandable` (array, **required**) — The extra-field's list that are not expanded and can be expanded into objects.
- `_meta` (object, **required**) — Meta information.
  - `totalCount` (integer, optional) — Total number of data items.
  - `pageCount` (integer, optional) — Total number of pages of data.
  - `currentPage` (integer, optional) — The current page number (1-based).
  - `perPage` (integer, optional) — The number of data items in each page.

Example:
```json
{
  "items": [
    {
      "id": 13,
      "number": 1001,
      "currency": "$",
      "po_number": null,
      "terms": "DUR",
      "customer_message": null,
      "notes": null,
      "pay_online_url": "https://app.servicefusion.com/invoiceOnline?id=WP7y6F6Ff48NqjQym4qX1maGXL_1oljugHAP0fNVaBg&key=0DtZ_Q5p4UZNqQHcx08U1k2dx8B3ZHKg3pBxavOtH61",
      "qbo_invoice_no": null,
      "qbo_sync_token": null,
      "qbo_synced_date": "2014-01-21T22:11:31+00:00",
      "qbo_id": null,
      "qbd_id": null,
      "total": 268.32,
      "is_paid": false,
      "date": "2014-01-21T00:00:00+00:00",
      "mail_send_date": null,
      "created_at": "2014-01-21T22:11:31+00:00",
      "updated_at": "2014-01-21T22:11:31+00:00",
      "customer": null,
      "customer_contact": null,
      "payment_terms": "Due Upon Receipt",
      "bill_to_customer_id": null,
      "bill_to_customer_location_id": null,
      "bill_to_customer_contact_id": null,
      "bill_to_email_id": null,
      "bill_to_phone_id": null
    }
  ],
  "_expandable": [],
  "_meta": {
    "totalCount": 50,
    "pageCount": 5,
    "currentPage": 1,
    "perPage": 10
  }
}
```

**Response 400:**
### 400 Bad Request (Client Error) The server cannot or will not process the request due to an apparent client error (e.g., malformed request syntax, size too large, invalid request message framing, or deceptive request routing).
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 400,
  "name": "Bad Request.",
  "message": "Your request is invalid."
}
```

**Response 401:**
### 401 Unauthorized (Client Error) Authentication is required and has failed or has not yet been provided.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 401,
  "name": "Unauthorized.",
  "message": "Your request was made with invalid credentials."
}
```

**Response 403:**
### 403 Forbidden (Client Error) Access to the requested resource is forbidden. The server understood the request, but will not fulfill it.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 403,
  "name": "Forbidden.",
  "message": "Login Required."
}
```

**Response 405:**
### 405 Method Not Allowed (Client Error) A request method is not supported for the requested resource. For example, a GET request on a form that requires data to be presented via POST.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 405,
  "name": "Method not allowed.",
  "message": "Method Not Allowed. This url can only handle the following request methods: GET.\n"
}
```

**Response 415:**
### 415 Unsupported Media Type (Client Error) The request entity has a media type which the server or resource does not support. For example, the client set request data as `application/xml`, but the server requires that request data use a different format.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 415,
  "name": "Unsupported Media Type.",
  "message": "None of your requested content types is supported."
}
```

**Response 429:**
### 429 Too Many Requests (Client Error) The user has sent too many requests in a given amount of time.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 429,
  "name": "Too Many Requests.",
  "message": "Rate limit exceeded."
}
```

**Response 500:**
### 500 Internal Server Error (Server Error) A generic error message, given when an unexpected condition was encountered and no more specific message is suitable.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 500,
  "name": "Internal server error.",
  "message": "Failed to create the object for unknown reason."
}
```

### GET `/v1/invoices/{invoice-id}`

Get a Invoice by identifier.

*Traits:* tra.invoice-fieldable, tra.formatable

**URI Parameters:**

- `invoice-id` (integer, **required**) — Used to send an identifier of the Invoice to be used.

**Query Parameters:**

- `fields` (string, optional) (default: `If not passed, will be displayed all available.`) Enum: `id`, `number`, `currency`, `po_number`, `terms`, `customer_message`, `notes`, `pay_online_url`, `qbo_invoice_no`, `qbo_sync_token`, `qbo_synced_date`, `qbo_id`, `qbd_id`, `total`, `is_paid`, `date`, `mail_send_date`, `created_at`, `updated_at`, `customer`, `customer_contact`, `payment_terms`, `bill_to_customer_id`, `bill_to_customer_location_id`, `bill_to_customer_contact_id`, `bill_to_email_id`, `bill_to_phone_id` — Used to send a list of fields to be displayed. Accepted value is comma-separated string. Example: `id,notes`
- `expand` (string, optional) (default: `If not passed, will be displayed nothing.`) — Used to send a list of extra-fields to be displayed. Accepted value is comma-separated string.
- `format` (string, optional) (default: `json`) Enum: `json`, `xml` — Used to send a format of data of the response. Do not use together with the `Accept` header.
- `access_token` (string, optional) — Used to send a valid OAuth 2 access token. Do not use together with the `Authorization` header. Example: `eyJz93a...k4laUWw`

**Response 200:**
### 200 OK (Success) Standard response for successful HTTP requests.
- Type: `object`

- `id` (integer, optional) — The invoice's identifier.
- `number` (integer, optional) — The invoice's number.
- `currency` (string, optional) — The invoice's currency.
- `po_number` (string, optional) — The invoice's po number.
- `terms` (string, optional) — The invoice's terms.
- `customer_message` (string, optional) — The invoice's customer message.
- `notes` (string, optional) — The invoice's notes.
- `pay_online_url` (string, optional) — The invoice's pay online url.
- `qbo_invoice_no` (integer, optional) — The invoice's qbo invoice no.
- `qbo_sync_token` (integer, optional) — The invoice's qbo sync token.
- `qbo_synced_date` (datetime, optional) — The invoice's qbo synced date.
- `qbo_id` (integer, optional) — The invoice's qbo class id.
- `qbd_id` (string, optional) — The invoice's qbd class id.
- `total` (number, optional) — The invoice's total.
- `is_paid` (boolean, optional) — The invoice's is paid flag.
- `date` (datetime, optional) — The invoice's date.
- `mail_send_date` (datetime, optional) — The invoice's mail send date.
- `created_at` (datetime, optional) — The invoice's created date.
- `updated_at` (datetime, optional) — The invoice's updated date.
- `customer` (string, optional) — The `header` of attached customer to the invoice (Note: `header` - [string] the customer's fields concatenated by pattern `{customer_name}`).
- `customer_contact` (string, optional) — The `header` of attached customer contact to the invoice (Note: `header` - [string] the customer contact's fields concatenated by pattern `{fname} {lname}` with space as separator).
- `payment_terms` (string, optional) — The `header` of attached payment term to the invoice (Note: `header` - [string] the payment term's fields concatenated by pattern `{name}`).
- `bill_to_customer_id` (integer, optional) — The `id` of attached bill to customer to the invoice (Note: `id` - [integer] the bill to customer's identifier).
- `bill_to_customer_location_id` (integer, optional) — The `id` of attached bill to customer location to the invoice (Note: `id` - [integer] the bill to customer location's identifier).
- `bill_to_customer_contact_id` (integer, optional) — The `id` of attached bill to customer contact to the invoice (Note: `id` - [integer] the bill to customer contact's identifier).
- `bill_to_email_id` (integer, optional) — The `id` of attached bill to email to the invoice (Note: `id` - [integer] the bill to email's identifier).
- `bill_to_phone_id` (integer, optional) — The `id` of attached bill to phone to the invoice (Note: `id` - [integer] the bill to phone's identifier).
- `_expandable` (array, **required**) — The extra-field's list that are not expanded and can be expanded into objects.

Example:
```json
{
  "id": 13,
  "number": 1001,
  "currency": "$",
  "po_number": null,
  "terms": "DUR",
  "customer_message": null,
  "notes": null,
  "pay_online_url": "https://app.servicefusion.com/invoiceOnline?id=WP7y6F6Ff48NqjQym4qX1maGXL_1oljugHAP0fNVaBg&key=0DtZ_Q5p4UZNqQHcx08U1k2dx8B3ZHKg3pBxavOtH61",
  "qbo_invoice_no": null,
  "qbo_sync_token": null,
  "qbo_synced_date": "2014-01-21T22:11:31+00:00",
  "qbo_id": null,
  "qbd_id": null,
  "total": 268.32,
  "is_paid": false,
  "date": "2014-01-21T00:00:00+00:00",
  "mail_send_date": null,
  "created_at": "2014-01-21T22:11:31+00:00",
  "updated_at": "2014-01-21T22:11:31+00:00",
  "customer": null,
  "customer_contact": null,
  "payment_terms": "Due Upon Receipt",
  "bill_to_customer_id": null,
  "bill_to_customer_location_id": null,
  "bill_to_customer_contact_id": null,
  "bill_to_email_id": null,
  "bill_to_phone_id": null,
  "_expandable": []
}
```

**Response 400:**
### 400 Bad Request (Client Error) The server cannot or will not process the request due to an apparent client error (e.g., malformed request syntax, size too large, invalid request message framing, or deceptive request routing).
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 400,
  "name": "Bad Request.",
  "message": "Your request is invalid."
}
```

**Response 401:**
### 401 Unauthorized (Client Error) Authentication is required and has failed or has not yet been provided.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 401,
  "name": "Unauthorized.",
  "message": "Your request was made with invalid credentials."
}
```

**Response 403:**
### 403 Forbidden (Client Error) Access to the requested resource is forbidden. The server understood the request, but will not fulfill it.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 403,
  "name": "Forbidden.",
  "message": "Login Required."
}
```

**Response 404:**
### 404 Not Found (Client Error) The requested resource could not be found but may be available in the future.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 404,
  "name": "Not Found.",
  "message": "Item not found."
}
```

**Response 405:**
### 405 Method Not Allowed (Client Error) A request method is not supported for the requested resource. For example, a GET request on a form that requires data to be presented via POST.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 405,
  "name": "Method not allowed.",
  "message": "Method Not Allowed. This url can only handle the following request methods: GET.\n"
}
```

**Response 415:**
### 415 Unsupported Media Type (Client Error) The request entity has a media type which the server or resource does not support. For example, the client set request data as `application/xml`, but the server requires that request data use a different format.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 415,
  "name": "Unsupported Media Type.",
  "message": "None of your requested content types is supported."
}
```

**Response 429:**
### 429 Too Many Requests (Client Error) The user has sent too many requests in a given amount of time.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 429,
  "name": "Too Many Requests.",
  "message": "Rate limit exceeded."
}
```

**Response 500:**
### 500 Internal Server Error (Server Error) A generic error message, given when an unexpected condition was encountered and no more specific message is suitable.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 500,
  "name": "Internal server error.",
  "message": "Failed to create the object for unknown reason."
}
```

### /payment-types

### GET `/v1/payment-types`

List all PaymentTypes matching query criteria, if provided,
otherwise list all PaymentTypes.

*Traits:* tra.paymentType-fieldable, tra.paymentType-sortable, tra.paymentType-filtrable, tra.formatable

**Query Parameters:**

- `page` (integer, optional) (default: `1`) — Used to send a page number to be displayed. Example: `2`
- `per-page` (integer, optional) (default: `10`) — Used to send a number of items displayed per page (min `1`, max `50`). Example: `20`
- `fields` (string, optional) (default: `If not passed, will be displayed all available.`) Enum: `id`, `code`, `short_name`, `type`, `is_custom` — Used to send a list of fields to be displayed. Accepted value is comma-separated string. Example: `id,short_name`
- `expand` (string, optional) (default: `If not passed, will be displayed nothing.`) — Used to send a list of extra-fields to be displayed. Accepted value is comma-separated string.
- `sort` (string, optional) (default: `id`) Enum: `id`, `code`, `short_name`, `type`, `is_custom` — Used to sort the results by given fields. Use minus `-` before field name to sort DESC. Accepted value is comma-separated string. Example: `type`
- `format` (string, optional) (default: `json`) Enum: `json`, `xml` — Used to send a format of data of the response. Do not use together with the `Accept` header.
- `access_token` (string, optional) — Used to send a valid OAuth 2 access token. Do not use together with the `Authorization` header. Example: `eyJz93a...k4laUWw`

**Response 200:**
### 200 OK (Success) Standard response for successful HTTP requests.
- Type: `object`

- `items` (array, **required**) — Collection envelope.
- `_expandable` (array, **required**) — The extra-field's list that are not expanded and can be expanded into objects.
- `_meta` (object, **required**) — Meta information.
  - `totalCount` (integer, optional) — Total number of data items.
  - `pageCount` (integer, optional) — Total number of pages of data.
  - `currentPage` (integer, optional) — The current page number (1-based).
  - `perPage` (integer, optional) — The number of data items in each page.

Example:
```json
{
  "items": [
    {
      "id": 980190989,
      "code": "BILL",
      "short_name": "Direct Bill",
      "type": "BILL",
      "is_custom": false
    }
  ],
  "_expandable": [],
  "_meta": {
    "totalCount": 50,
    "pageCount": 5,
    "currentPage": 1,
    "perPage": 10
  }
}
```

**Response 400:**
### 400 Bad Request (Client Error) The server cannot or will not process the request due to an apparent client error (e.g., malformed request syntax, size too large, invalid request message framing, or deceptive request routing).
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 400,
  "name": "Bad Request.",
  "message": "Your request is invalid."
}
```

**Response 401:**
### 401 Unauthorized (Client Error) Authentication is required and has failed or has not yet been provided.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 401,
  "name": "Unauthorized.",
  "message": "Your request was made with invalid credentials."
}
```

**Response 403:**
### 403 Forbidden (Client Error) Access to the requested resource is forbidden. The server understood the request, but will not fulfill it.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 403,
  "name": "Forbidden.",
  "message": "Login Required."
}
```

**Response 405:**
### 405 Method Not Allowed (Client Error) A request method is not supported for the requested resource. For example, a GET request on a form that requires data to be presented via POST.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 405,
  "name": "Method not allowed.",
  "message": "Method Not Allowed. This url can only handle the following request methods: GET.\n"
}
```

**Response 415:**
### 415 Unsupported Media Type (Client Error) The request entity has a media type which the server or resource does not support. For example, the client set request data as `application/xml`, but the server requires that request data use a different format.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 415,
  "name": "Unsupported Media Type.",
  "message": "None of your requested content types is supported."
}
```

**Response 429:**
### 429 Too Many Requests (Client Error) The user has sent too many requests in a given amount of time.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 429,
  "name": "Too Many Requests.",
  "message": "Rate limit exceeded."
}
```

**Response 500:**
### 500 Internal Server Error (Server Error) A generic error message, given when an unexpected condition was encountered and no more specific message is suitable.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 500,
  "name": "Internal server error.",
  "message": "Failed to create the object for unknown reason."
}
```

### GET `/v1/payment-types/{payment-type-id}`

Get a PaymentType by identifier.

*Traits:* tra.paymentType-fieldable, tra.formatable

**URI Parameters:**

- `payment-type-id` (integer, **required**) — Used to send an identifier of the PaymentType to be used.

**Query Parameters:**

- `fields` (string, optional) (default: `If not passed, will be displayed all available.`) Enum: `id`, `code`, `short_name`, `type`, `is_custom` — Used to send a list of fields to be displayed. Accepted value is comma-separated string. Example: `id,short_name`
- `expand` (string, optional) (default: `If not passed, will be displayed nothing.`) — Used to send a list of extra-fields to be displayed. Accepted value is comma-separated string.
- `format` (string, optional) (default: `json`) Enum: `json`, `xml` — Used to send a format of data of the response. Do not use together with the `Accept` header.
- `access_token` (string, optional) — Used to send a valid OAuth 2 access token. Do not use together with the `Authorization` header. Example: `eyJz93a...k4laUWw`

**Response 200:**
### 200 OK (Success) Standard response for successful HTTP requests.
- Type: `object`

- `id` (integer, optional) — The type's identifier.
- `code` (string, optional) — The type's code.
- `short_name` (string, optional) — The type's short name.
- `type` (string, optional) — The type's type.
- `is_custom` (boolean, optional) — The type's is custom flag.
- `_expandable` (array, **required**) — The extra-field's list that are not expanded and can be expanded into objects.

Example:
```json
{
  "id": 980190989,
  "code": "BILL",
  "short_name": "Direct Bill",
  "type": "BILL",
  "is_custom": false,
  "_expandable": []
}
```

**Response 400:**
### 400 Bad Request (Client Error) The server cannot or will not process the request due to an apparent client error (e.g., malformed request syntax, size too large, invalid request message framing, or deceptive request routing).
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 400,
  "name": "Bad Request.",
  "message": "Your request is invalid."
}
```

**Response 401:**
### 401 Unauthorized (Client Error) Authentication is required and has failed or has not yet been provided.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 401,
  "name": "Unauthorized.",
  "message": "Your request was made with invalid credentials."
}
```

**Response 403:**
### 403 Forbidden (Client Error) Access to the requested resource is forbidden. The server understood the request, but will not fulfill it.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 403,
  "name": "Forbidden.",
  "message": "Login Required."
}
```

**Response 404:**
### 404 Not Found (Client Error) The requested resource could not be found but may be available in the future.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 404,
  "name": "Not Found.",
  "message": "Item not found."
}
```

**Response 405:**
### 405 Method Not Allowed (Client Error) A request method is not supported for the requested resource. For example, a GET request on a form that requires data to be presented via POST.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 405,
  "name": "Method not allowed.",
  "message": "Method Not Allowed. This url can only handle the following request methods: GET.\n"
}
```

**Response 415:**
### 415 Unsupported Media Type (Client Error) The request entity has a media type which the server or resource does not support. For example, the client set request data as `application/xml`, but the server requires that request data use a different format.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 415,
  "name": "Unsupported Media Type.",
  "message": "None of your requested content types is supported."
}
```

**Response 429:**
### 429 Too Many Requests (Client Error) The user has sent too many requests in a given amount of time.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 429,
  "name": "Too Many Requests.",
  "message": "Rate limit exceeded."
}
```

**Response 500:**
### 500 Internal Server Error (Server Error) A generic error message, given when an unexpected condition was encountered and no more specific message is suitable.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 500,
  "name": "Internal server error.",
  "message": "Failed to create the object for unknown reason."
}
```

### /sources

### GET `/v1/sources`

List all Sources matching query criteria, if provided,
otherwise list all Sources.

*Traits:* tra.source-fieldable, tra.source-sortable, tra.source-filtrable, tra.formatable

**Query Parameters:**

- `page` (integer, optional) (default: `1`) — Used to send a page number to be displayed. Example: `2`
- `per-page` (integer, optional) (default: `10`) — Used to send a number of items displayed per page (min `1`, max `50`). Example: `20`
- `fields` (string, optional) (default: `If not passed, will be displayed all available.`) Enum: `id`, `short_name`, `long_name` — Used to send a list of fields to be displayed. Accepted value is comma-separated string. Example: `id,short_name`
- `expand` (string, optional) (default: `If not passed, will be displayed nothing.`) — Used to send a list of extra-fields to be displayed. Accepted value is comma-separated string.
- `sort` (string, optional) (default: `id`) Enum: `id`, `short_name`, `long_name` — Used to sort the results by given fields. Use minus `-` before field name to sort DESC. Accepted value is comma-separated string. Example: `id,-long_name`
- `format` (string, optional) (default: `json`) Enum: `json`, `xml` — Used to send a format of data of the response. Do not use together with the `Accept` header.
- `access_token` (string, optional) — Used to send a valid OAuth 2 access token. Do not use together with the `Authorization` header. Example: `eyJz93a...k4laUWw`

**Response 200:**
### 200 OK (Success) Standard response for successful HTTP requests.
- Type: `object`

- `items` (array, **required**) — Collection envelope.
- `_expandable` (array, **required**) — The extra-field's list that are not expanded and can be expanded into objects.
- `_meta` (object, **required**) — Meta information.
  - `totalCount` (integer, optional) — Total number of data items.
  - `pageCount` (integer, optional) — Total number of pages of data.
  - `currentPage` (integer, optional) — The current page number (1-based).
  - `perPage` (integer, optional) — The number of data items in each page.

Example:
```json
{
  "items": [
    {
      "id": 980192647,
      "short_name": "Source for Testing",
      "long_name": "Long Description of New Testing Source"
    }
  ],
  "_expandable": [],
  "_meta": {
    "totalCount": 50,
    "pageCount": 5,
    "currentPage": 1,
    "perPage": 10
  }
}
```

**Response 400:**
### 400 Bad Request (Client Error) The server cannot or will not process the request due to an apparent client error (e.g., malformed request syntax, size too large, invalid request message framing, or deceptive request routing).
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 400,
  "name": "Bad Request.",
  "message": "Your request is invalid."
}
```

**Response 401:**
### 401 Unauthorized (Client Error) Authentication is required and has failed or has not yet been provided.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 401,
  "name": "Unauthorized.",
  "message": "Your request was made with invalid credentials."
}
```

**Response 403:**
### 403 Forbidden (Client Error) Access to the requested resource is forbidden. The server understood the request, but will not fulfill it.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 403,
  "name": "Forbidden.",
  "message": "Login Required."
}
```

**Response 405:**
### 405 Method Not Allowed (Client Error) A request method is not supported for the requested resource. For example, a GET request on a form that requires data to be presented via POST.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 405,
  "name": "Method not allowed.",
  "message": "Method Not Allowed. This url can only handle the following request methods: GET.\n"
}
```

**Response 415:**
### 415 Unsupported Media Type (Client Error) The request entity has a media type which the server or resource does not support. For example, the client set request data as `application/xml`, but the server requires that request data use a different format.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 415,
  "name": "Unsupported Media Type.",
  "message": "None of your requested content types is supported."
}
```

**Response 429:**
### 429 Too Many Requests (Client Error) The user has sent too many requests in a given amount of time.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 429,
  "name": "Too Many Requests.",
  "message": "Rate limit exceeded."
}
```

**Response 500:**
### 500 Internal Server Error (Server Error) A generic error message, given when an unexpected condition was encountered and no more specific message is suitable.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 500,
  "name": "Internal server error.",
  "message": "Failed to create the object for unknown reason."
}
```

### GET `/v1/sources/{source-id}`

Get a Source by identifier.

*Traits:* tra.source-fieldable, tra.formatable

**URI Parameters:**

- `source-id` (integer, **required**) — Used to send an identifier of the Source to be used.

**Query Parameters:**

- `fields` (string, optional) (default: `If not passed, will be displayed all available.`) Enum: `id`, `short_name`, `long_name` — Used to send a list of fields to be displayed. Accepted value is comma-separated string. Example: `id,short_name`
- `expand` (string, optional) (default: `If not passed, will be displayed nothing.`) — Used to send a list of extra-fields to be displayed. Accepted value is comma-separated string.
- `format` (string, optional) (default: `json`) Enum: `json`, `xml` — Used to send a format of data of the response. Do not use together with the `Accept` header.
- `access_token` (string, optional) — Used to send a valid OAuth 2 access token. Do not use together with the `Authorization` header. Example: `eyJz93a...k4laUWw`

**Response 200:**
### 200 OK (Success) Standard response for successful HTTP requests.
- Type: `object`

- `id` (integer, optional) — The source's identifier.
- `short_name` (string, optional) — The source's short name.
- `long_name` (string, optional) — The source's long name.
- `_expandable` (array, **required**) — The extra-field's list that are not expanded and can be expanded into objects.

Example:
```json
{
  "id": 980192647,
  "short_name": "Source for Testing",
  "long_name": "Long Description of New Testing Source",
  "_expandable": []
}
```

**Response 400:**
### 400 Bad Request (Client Error) The server cannot or will not process the request due to an apparent client error (e.g., malformed request syntax, size too large, invalid request message framing, or deceptive request routing).
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 400,
  "name": "Bad Request.",
  "message": "Your request is invalid."
}
```

**Response 401:**
### 401 Unauthorized (Client Error) Authentication is required and has failed or has not yet been provided.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 401,
  "name": "Unauthorized.",
  "message": "Your request was made with invalid credentials."
}
```

**Response 403:**
### 403 Forbidden (Client Error) Access to the requested resource is forbidden. The server understood the request, but will not fulfill it.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 403,
  "name": "Forbidden.",
  "message": "Login Required."
}
```

**Response 404:**
### 404 Not Found (Client Error) The requested resource could not be found but may be available in the future.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 404,
  "name": "Not Found.",
  "message": "Item not found."
}
```

**Response 405:**
### 405 Method Not Allowed (Client Error) A request method is not supported for the requested resource. For example, a GET request on a form that requires data to be presented via POST.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 405,
  "name": "Method not allowed.",
  "message": "Method Not Allowed. This url can only handle the following request methods: GET.\n"
}
```

**Response 415:**
### 415 Unsupported Media Type (Client Error) The request entity has a media type which the server or resource does not support. For example, the client set request data as `application/xml`, but the server requires that request data use a different format.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 415,
  "name": "Unsupported Media Type.",
  "message": "None of your requested content types is supported."
}
```

**Response 429:**
### 429 Too Many Requests (Client Error) The user has sent too many requests in a given amount of time.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 429,
  "name": "Too Many Requests.",
  "message": "Rate limit exceeded."
}
```

**Response 500:**
### 500 Internal Server Error (Server Error) A generic error message, given when an unexpected condition was encountered and no more specific message is suitable.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 500,
  "name": "Internal server error.",
  "message": "Failed to create the object for unknown reason."
}
```

### /techs

### GET `/v1/techs`

List all Techs matching query criteria, if provided,
otherwise list all Techs.

*Traits:* tra.tech-fieldable, tra.tech-sortable, tra.tech-filtrable, tra.formatable

**Query Parameters:**

- `page` (integer, optional) (default: `1`) — Used to send a page number to be displayed. Example: `2`
- `per-page` (integer, optional) (default: `10`) — Used to send a number of items displayed per page (min `1`, max `50`). Example: `20`
- `fields` (string, optional) (default: `If not passed, will be displayed all available.`) Enum: `id`, `first_name`, `last_name`, `nickname_on_workorder`, `nickname_on_dispatch`, `color_code`, `email`, `phone_1`, `phone_2`, `gender`, `department`, `title`, `bio`, `is_phone_1_mobile`, `is_phone_1_visible_to_client`, `is_phone_2_mobile`, `is_phone_2_visible_to_client`, `is_sales_rep`, `is_field_worker`, `created_at`, `updated_at` — Used to send a list of fields to be displayed. Accepted value is comma-separated string. Example: `id,created_at,updated_at`
- `expand` (string, optional) (default: `If not passed, will be displayed nothing.`) — Used to send a list of extra-fields to be displayed. Accepted value is comma-separated string.
- `sort` (string, optional) (default: `id`) Enum: `id`, `first_name`, `last_name`, `nickname_on_workorder`, `nickname_on_dispatch`, `color_code`, `email`, `phone_1`, `phone_2`, `gender`, `department`, `title`, `bio`, `is_phone_1_mobile`, `is_phone_1_visible_to_client`, `is_phone_2_mobile`, `is_phone_2_visible_to_client`, `is_sales_rep`, `is_field_worker`, `created_at`, `updated_at` — Used to sort the results by given fields. Use minus `-` before field name to sort DESC. Accepted value is comma-separated string. Example: `created_at,-first_name`
- `filters[first_name]` (string, optional) — Used to filter results by given first name (partial match). Example: `Justin`
- `filters[last_name]` (string, optional) — Used to filter results by given last name (partial match). Example: `Wormell`
- `filters[email]` (string, optional) — Used to filter results by given email (partial match). Example: `@servicefusion.com`
- `filters[nickname_on_workorder]` (string, optional) — Used to filter results by given nickname on workorder (partial match). Example: `Workorder Heating`
- `filters[nickname_on_dispatch]` (string, optional) — Used to filter results by given nickname on dispatch (partial match). Example: `Dispatch Heating`
- `format` (string, optional) (default: `json`) Enum: `json`, `xml` — Used to send a format of data of the response. Do not use together with the `Accept` header.
- `access_token` (string, optional) — Used to send a valid OAuth 2 access token. Do not use together with the `Authorization` header. Example: `eyJz93a...k4laUWw`

**Response 200:**
### 200 OK (Success) Standard response for successful HTTP requests.
- Type: `object`

- `items` (array, **required**) — Collection envelope.
- `_expandable` (array, **required**) — The extra-field's list that are not expanded and can be expanded into objects.
- `_meta` (object, **required**) — Meta information.
  - `totalCount` (integer, optional) — Total number of data items.
  - `pageCount` (integer, optional) — Total number of pages of data.
  - `currentPage` (integer, optional) — The current page number (1-based).
  - `perPage` (integer, optional) — The number of data items in each page.

Example:
```json
{
  "items": [
    {
      "id": 1472289,
      "first_name": "Justin",
      "last_name": "Wormell",
      "nickname_on_workorder": "Workorder Heating",
      "nickname_on_dispatch": "Dispatch Heating",
      "color_code": "#356a9f",
      "email": "justin@servicefusion.com",
      "phone_1": "232-323-123",
      "phone_2": "444-444-4444",
      "gender": "F",
      "department": "Plumbing",
      "title": "Service Tech",
      "bio": "Here is a short bio on the tech that you can include along with your confirmations",
      "is_phone_1_mobile": false,
      "is_phone_1_visible_to_client": false,
      "is_phone_2_mobile": true,
      "is_phone_2_visible_to_client": true,
      "is_sales_rep": false,
      "is_field_worker": true,
      "created_at": "2018-08-07T18:31:28+00:00",
      "updated_at": "2018-08-07T18:31:28+00:00"
    }
  ],
  "_expandable": [],
  "_meta": {
    "totalCount": 50,
    "pageCount": 5,
    "currentPage": 1,
    "perPage": 10
  }
}
```

**Response 400:**
### 400 Bad Request (Client Error) The server cannot or will not process the request due to an apparent client error (e.g., malformed request syntax, size too large, invalid request message framing, or deceptive request routing).
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 400,
  "name": "Bad Request.",
  "message": "Your request is invalid."
}
```

**Response 401:**
### 401 Unauthorized (Client Error) Authentication is required and has failed or has not yet been provided.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 401,
  "name": "Unauthorized.",
  "message": "Your request was made with invalid credentials."
}
```

**Response 403:**
### 403 Forbidden (Client Error) Access to the requested resource is forbidden. The server understood the request, but will not fulfill it.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 403,
  "name": "Forbidden.",
  "message": "Login Required."
}
```

**Response 405:**
### 405 Method Not Allowed (Client Error) A request method is not supported for the requested resource. For example, a GET request on a form that requires data to be presented via POST.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 405,
  "name": "Method not allowed.",
  "message": "Method Not Allowed. This url can only handle the following request methods: GET.\n"
}
```

**Response 415:**
### 415 Unsupported Media Type (Client Error) The request entity has a media type which the server or resource does not support. For example, the client set request data as `application/xml`, but the server requires that request data use a different format.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 415,
  "name": "Unsupported Media Type.",
  "message": "None of your requested content types is supported."
}
```

**Response 429:**
### 429 Too Many Requests (Client Error) The user has sent too many requests in a given amount of time.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 429,
  "name": "Too Many Requests.",
  "message": "Rate limit exceeded."
}
```

**Response 500:**
### 500 Internal Server Error (Server Error) A generic error message, given when an unexpected condition was encountered and no more specific message is suitable.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 500,
  "name": "Internal server error.",
  "message": "Failed to create the object for unknown reason."
}
```

### GET `/v1/techs/{tech-id}`

Get a Tech by identifier.

*Traits:* tra.tech-fieldable, tra.formatable

**URI Parameters:**

- `tech-id` (integer, **required**) — Used to send an identifier of the Tech to be used.

**Query Parameters:**

- `fields` (string, optional) (default: `If not passed, will be displayed all available.`) Enum: `id`, `first_name`, `last_name`, `nickname_on_workorder`, `nickname_on_dispatch`, `color_code`, `email`, `phone_1`, `phone_2`, `gender`, `department`, `title`, `bio`, `is_phone_1_mobile`, `is_phone_1_visible_to_client`, `is_phone_2_mobile`, `is_phone_2_visible_to_client`, `is_sales_rep`, `is_field_worker`, `created_at`, `updated_at` — Used to send a list of fields to be displayed. Accepted value is comma-separated string. Example: `id,created_at,updated_at`
- `expand` (string, optional) (default: `If not passed, will be displayed nothing.`) — Used to send a list of extra-fields to be displayed. Accepted value is comma-separated string.
- `format` (string, optional) (default: `json`) Enum: `json`, `xml` — Used to send a format of data of the response. Do not use together with the `Accept` header.
- `access_token` (string, optional) — Used to send a valid OAuth 2 access token. Do not use together with the `Authorization` header. Example: `eyJz93a...k4laUWw`

**Response 200:**
### 200 OK (Success) Standard response for successful HTTP requests.
- Type: `object`

- `id` (integer, optional) — The tech's identifier.
- `first_name` (string, optional) — The tech's first name.
- `last_name` (string, optional) — The tech's last name.
- `nickname_on_workorder` (string, optional) — The tech's nickname on workorder.
- `nickname_on_dispatch` (string, optional) — The tech's nickname on dispatch.
- `color_code` (string, optional) — The tech's color code.
- `email` (string, optional) — The tech's email.
- `phone_1` (string, optional) — The tech's phone 1.
- `phone_2` (string, optional) — The tech's phone 2.
- `gender` (string, optional) — The tech's gender.
- `department` (string, optional) — The tech's department.
- `title` (string, optional) — The tech's title.
- `bio` (string, optional) — The tech's bio.
- `is_phone_1_mobile` (boolean, optional) — The tech's is phone 1 mobile flag.
- `is_phone_1_visible_to_client` (boolean, optional) — The tech's is phone 1 visible to client flag.
- `is_phone_2_mobile` (boolean, optional) — The tech's is phone 2 mobile flag.
- `is_phone_2_visible_to_client` (boolean, optional) — The tech's is phone 2 visible to client flag.
- `is_sales_rep` (boolean, optional) — The tech's is sales rep flag.
- `is_field_worker` (boolean, optional) — The tech's is field worker flag.
- `created_at` (datetime, optional) — The tech's created date.
- `updated_at` (datetime, optional) — The tech's updated date.
- `_expandable` (array, **required**) — The extra-field's list that are not expanded and can be expanded into objects.

Example:
```json
{
  "id": 1472289,
  "first_name": "Justin",
  "last_name": "Wormell",
  "nickname_on_workorder": "Workorder Heating",
  "nickname_on_dispatch": "Dispatch Heating",
  "color_code": "#356a9f",
  "email": "justin@servicefusion.com",
  "phone_1": "232-323-123",
  "phone_2": "444-444-4444",
  "gender": "F",
  "department": "Plumbing",
  "title": "Service Tech",
  "bio": "Here is a short bio on the tech that you can include along with your confirmations",
  "is_phone_1_mobile": false,
  "is_phone_1_visible_to_client": false,
  "is_phone_2_mobile": true,
  "is_phone_2_visible_to_client": true,
  "is_sales_rep": false,
  "is_field_worker": true,
  "created_at": "2018-08-07T18:31:28+00:00",
  "updated_at": "2018-08-07T18:31:28+00:00",
  "_expandable": []
}
```

**Response 400:**
### 400 Bad Request (Client Error) The server cannot or will not process the request due to an apparent client error (e.g., malformed request syntax, size too large, invalid request message framing, or deceptive request routing).
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 400,
  "name": "Bad Request.",
  "message": "Your request is invalid."
}
```

**Response 401:**
### 401 Unauthorized (Client Error) Authentication is required and has failed or has not yet been provided.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 401,
  "name": "Unauthorized.",
  "message": "Your request was made with invalid credentials."
}
```

**Response 403:**
### 403 Forbidden (Client Error) Access to the requested resource is forbidden. The server understood the request, but will not fulfill it.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 403,
  "name": "Forbidden.",
  "message": "Login Required."
}
```

**Response 404:**
### 404 Not Found (Client Error) The requested resource could not be found but may be available in the future.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 404,
  "name": "Not Found.",
  "message": "Item not found."
}
```

**Response 405:**
### 405 Method Not Allowed (Client Error) A request method is not supported for the requested resource. For example, a GET request on a form that requires data to be presented via POST.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 405,
  "name": "Method not allowed.",
  "message": "Method Not Allowed. This url can only handle the following request methods: GET.\n"
}
```

**Response 415:**
### 415 Unsupported Media Type (Client Error) The request entity has a media type which the server or resource does not support. For example, the client set request data as `application/xml`, but the server requires that request data use a different format.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 415,
  "name": "Unsupported Media Type.",
  "message": "None of your requested content types is supported."
}
```

**Response 429:**
### 429 Too Many Requests (Client Error) The user has sent too many requests in a given amount of time.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 429,
  "name": "Too Many Requests.",
  "message": "Rate limit exceeded."
}
```

**Response 500:**
### 500 Internal Server Error (Server Error) A generic error message, given when an unexpected condition was encountered and no more specific message is suitable.
- Type: `object`

- `code` (integer, optional) — The error code associated with the error.
- `name` (string, optional) — The error name associated with the error.
- `message` (string, optional) — The error message associated with the error.

Example:
```json
{
  "code": 500,
  "name": "Internal server error.",
  "message": "Failed to create the object for unknown reason."
}
```

---

## Data Types

### OAuthToken

An authentication schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `access_token` | `string` | optional | The access token string as issued by the authorization server. |
| `token_type` | `string` | optional | The type of token this is. |
| `expires_in` | `integer` | optional | The duration of time the access token is granted for. |
| `refresh_token` | `string` | optional | When an access token expires (exceeds the `expires_in` time), the `refresh_token` is used to obtain a new access token. |

**Example:**
```json
{
  "access_token": "-2Mt0oncDlmsQ9D3QZ290MiV9sK_vRDR",
  "token_type": "Bearer",
  "expires_in": 3600,
  "refresh_token": "h1BYTeBr0VA9QlQdq8EtBI2y2GzELyJH"
}
```

### OAuthTokenError

An authentication error's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `error` | `string` | optional | The error title. |
| `error_description` | `string` | optional | The error description. |

**Example:**
```json
{
  "error": "invalid_client",
  "error_description": "Invalid client's id or secret."
}
```

### Error

An error's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `code` | `integer` | optional | The error code associated with the error. |
| `name` | `string` | optional | The error name associated with the error. |
| `message` | `string` | optional | The error message associated with the error. |

### 400Error

Bad request client's error schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `code` | `integer` | optional | The error code associated with the error. |
| `name` | `string` | optional | The error name associated with the error. |
| `message` | `string` | optional | The error message associated with the error. |

**Example:**
```json
{
  "code": 400,
  "name": "Bad Request.",
  "message": "Your request is invalid."
}
```

### 404Error

Not found client's error schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `code` | `integer` | optional | The error code associated with the error. |
| `name` | `string` | optional | The error name associated with the error. |
| `message` | `string` | optional | The error message associated with the error. |

**Example:**
```json
{
  "code": 404,
  "name": "Not Found.",
  "message": "Item not found."
}
```

### 405Error

Method not allowed client's error schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `code` | `integer` | optional | The error code associated with the error. |
| `name` | `string` | optional | The error name associated with the error. |
| `message` | `string` | optional | The error message associated with the error. |

**Example:**
```json
{
  "code": 405,
  "name": "Method not allowed.",
  "message": "Method Not Allowed. This url can only handle the following request methods: GET.\n"
}
```

### 415Error

Unsupported media type client's error schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `code` | `integer` | optional | The error code associated with the error. |
| `name` | `string` | optional | The error name associated with the error. |
| `message` | `string` | optional | The error message associated with the error. |

**Example:**
```json
{
  "code": 415,
  "name": "Unsupported Media Type.",
  "message": "None of your requested content types is supported."
}
```

### 422Error

Unprocessable entity client's error schema.

**Base type:** `array`

**Example:**
```json
[
  {
    "field": "name",
    "message": "Name is too long (maximum is 45 characters)."
  }
]
```

### 429Error

Too many requests client's error schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `code` | `integer` | optional | The error code associated with the error. |
| `name` | `string` | optional | The error name associated with the error. |
| `message` | `string` | optional | The error message associated with the error. |

**Example:**
```json
{
  "code": 429,
  "name": "Too Many Requests.",
  "message": "Rate limit exceeded."
}
```

### 500Error

Internal server's error schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `code` | `integer` | optional | The error code associated with the error. |
| `name` | `string` | optional | The error name associated with the error. |
| `message` | `string` | optional | The error message associated with the error. |

**Example:**
```json
{
  "code": 500,
  "name": "Internal server error.",
  "message": "Failed to create the object for unknown reason."
}
```

### Agent

An agent's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | The agent's identifier. |
| `first_name` | `string` | optional | The agent's first name. |
| `last_name` | `string` | optional | The agent's last name. |

**Example:**
```json
[
  {
    "id": 31,
    "first_name": "Justin",
    "last_name": "Wormell"
  },
  {
    "id": 32,
    "first_name": "John",
    "last_name": "Theowner"
  }
]
```

### AgentBody

An agent's body schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | Used to send the agent's identifier that will be searched. If this field is set then the entry will be searched by it, otherwise the search will be performed by its full name. (default: `If not passed, it takes the value from full name search entry.`) |
| `first_name` | `string` | optional | Used to send the agent's first name that will be searched. Required field for full name search. (default: `If field `id` passed, it takes the value from search entry.`) |
| `last_name` | `string` | optional | Used to send the agent's last name that will be searched. Required field for full name search. (default: `If field `id` passed, it takes the value from search entry.`) |

**Example:**
```json
[
  {
    "id": 31
  },
  {
    "first_name": "John",
    "last_name": "Theowner"
  }
]
```

### AssignedTech

An assigned tech's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | The assigned tech's identifier. |
| `first_name` | `string` | optional | The assigned tech's first name. |
| `last_name` | `string` | optional | The assigned tech's last name. |

**Example:**
```json
[
  {
    "id": 31,
    "first_name": "Justin",
    "last_name": "Wormell"
  },
  {
    "id": 32,
    "first_name": "John",
    "last_name": "Theowner"
  }
]
```

### AssignedTechBody

An assigned tech's body schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | Used to send the assigned tech's identifier that will be searched. If this field is set then the entry will be searched by it, otherwise the search will be performed by its full name. (default: `If not passed, it takes the value from full name search entry.`) |
| `first_name` | `string` | optional | Used to send the assigned tech's first name that will be searched. Required field for full name search. (default: `If field `id` passed, it takes the value from search entry.`) |
| `last_name` | `string` | optional | Used to send the assigned tech's last name that will be searched. Required field for full name search. (default: `If field `id` passed, it takes the value from search entry.`) |

**Example:**
```json
[
  {
    "id": 31
  },
  {
    "first_name": "John",
    "last_name": "Theowner"
  }
]
```

### CalendarTask

A calendar task's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | The calendar task's identifier. |
| `type` | `string` | optional | The calendar task's type. |
| `description` | `string` | optional | The calendar task's description. |
| `start_time` | `string` | optional | The calendar task's start time. |
| `end_time` | `string` | optional | The calendar task's end time. |
| `start_date` | `datetime` | optional | The calendar task's start date. |
| `end_date` | `datetime` | optional | The calendar task's end date. |
| `created_at` | `datetime` | optional | The calendar task's created date. |
| `updated_at` | `datetime` | optional | The calendar task's updated date. |
| `is_public` | `boolean` | optional | The calendar task's is public flag. |
| `is_completed` | `boolean` | optional | The calendar task's is completed flag. |
| `repeat_id` | `integer` | optional | The calendar task's repeat id. |
| `users_id` | `array` | **required** | The calendar task's users list of identifiers. |
| `customers_id` | `array` | **required** | The calendar task's customers list of identifiers. |
| `jobs_id` | `array` | **required** | The calendar task's jobs list of identifiers. |
| `estimates_id` | `array` | **required** | The calendar task's estimates list of identifiers. |
| `repeat` | `object` | optional | The calendar task's repeat. |
| `repeat.id` | `integer` | optional | The repeat's identifier. |
| `repeat.repeat_type` | `string` | optional | The repeat's type. |
| `repeat.repeat_frequency` | `integer` | optional | The repeat's frequency. |
| `repeat.repeat_weekly_days` | `array` | **required** | The repeat's weekly days list. |
| `repeat.repeat_monthly_type` | `string` | optional | The repeat's monthly type. |
| `repeat.stop_repeat_type` | `string` | optional | The repeat's stop type. |
| `repeat.stop_repeat_on_occurrence` | `integer` | optional | The repeat's stop on occurrence. |
| `repeat.stop_repeat_on_date` | `datetime` | optional | The repeat's stop on date. |
| `repeat.start_date` | `datetime` | optional | The repeat's start date. |
| `repeat.end_date` | `datetime` | optional | The repeat's end date. |

**Example:**
```json
{
  "id": 16546,
  "type": "Call",
  "description": "Zapier task note",
  "start_time": "10:00",
  "end_time": "22:00",
  "start_date": "2021-05-01",
  "end_date": null,
  "created_at": "2021-06-22T11:02:32+00:00",
  "updated_at": "2021-06-22T11:02:32+00:00",
  "is_public": false,
  "is_completed": false,
  "repeat_id": 99,
  "users_id": [
    980190972,
    980190979
  ],
  "customers_id": [
    9303,
    842180
  ],
  "jobs_id": [
    1152721,
    1152722
  ],
  "estimates_id": [
    1152212,
    1152932
  ],
  "repeat": {
    "id": 92,
    "repeat_type": "Daily",
    "repeat_frequency": 2,
    "repeat_weekly_days": [],
    "repeat_monthly_type": null,
    "stop_repeat_type": "On Occurrence",
    "stop_repeat_on_occurrence": 10,
    "stop_repeat_on_date": null,
    "start_date": "2021-05-27T00:00:00+00:00",
    "end_date": "2021-06-14T00:00:00+00:00"
  }
}
```

### CalendarTaskView

A calendar task's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | The calendar task's identifier. |
| `type` | `string` | optional | The calendar task's type. |
| `description` | `string` | optional | The calendar task's description. |
| `start_time` | `string` | optional | The calendar task's start time. |
| `end_time` | `string` | optional | The calendar task's end time. |
| `start_date` | `datetime` | optional | The calendar task's start date. |
| `end_date` | `datetime` | optional | The calendar task's end date. |
| `created_at` | `datetime` | optional | The calendar task's created date. |
| `updated_at` | `datetime` | optional | The calendar task's updated date. |
| `is_public` | `boolean` | optional | The calendar task's is public flag. |
| `is_completed` | `boolean` | optional | The calendar task's is completed flag. |
| `repeat_id` | `integer` | optional | The calendar task's repeat id. |
| `users_id` | `array` | **required** | The calendar task's users list of identifiers. |
| `customers_id` | `array` | **required** | The calendar task's customers list of identifiers. |
| `jobs_id` | `array` | **required** | The calendar task's jobs list of identifiers. |
| `estimates_id` | `array` | **required** | The calendar task's estimates list of identifiers. |
| `repeat` | `object` | optional | The calendar task's repeat. |
| `repeat.id` | `integer` | optional | The repeat's identifier. |
| `repeat.repeat_type` | `string` | optional | The repeat's type. |
| `repeat.repeat_frequency` | `integer` | optional | The repeat's frequency. |
| `repeat.repeat_weekly_days` | `array` | **required** | The repeat's weekly days list. |
| `repeat.repeat_monthly_type` | `string` | optional | The repeat's monthly type. |
| `repeat.stop_repeat_type` | `string` | optional | The repeat's stop type. |
| `repeat.stop_repeat_on_occurrence` | `integer` | optional | The repeat's stop on occurrence. |
| `repeat.stop_repeat_on_date` | `datetime` | optional | The repeat's stop on date. |
| `repeat.start_date` | `datetime` | optional | The repeat's start date. |
| `repeat.end_date` | `datetime` | optional | The repeat's end date. |
| `_expandable` | `array` | **required** | The extra-field's list that are not expanded and can be expanded into objects. |

**Example:**
```json
{
  "id": 16546,
  "type": "Call",
  "description": "Zapier task note",
  "start_time": "10:00",
  "end_time": "22:00",
  "start_date": "2021-05-01",
  "end_date": null,
  "created_at": "2021-06-22T11:02:32+00:00",
  "updated_at": "2021-06-22T11:02:32+00:00",
  "is_public": false,
  "is_completed": false,
  "repeat_id": 99,
  "users_id": [
    980190972,
    980190979
  ],
  "customers_id": [
    9303,
    842180
  ],
  "jobs_id": [
    1152721,
    1152722
  ],
  "estimates_id": [
    1152212,
    1152932
  ],
  "repeat": {
    "id": 92,
    "repeat_type": "Daily",
    "repeat_frequency": 2,
    "repeat_weekly_days": [],
    "repeat_monthly_type": null,
    "stop_repeat_type": "On Occurrence",
    "stop_repeat_on_occurrence": 10,
    "stop_repeat_on_date": null,
    "start_date": "2021-05-27T00:00:00+00:00",
    "end_date": "2021-06-14T00:00:00+00:00"
  },
  "_expandable": [
    "repeat"
  ]
}
```

### CalendarTaskRepeat

A calendar task repeat's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | The repeat's identifier. |
| `repeat_type` | `string` | optional | The repeat's type. |
| `repeat_frequency` | `integer` | optional | The repeat's frequency. |
| `repeat_weekly_days` | `array` | **required** | The repeat's weekly days list. |
| `repeat_monthly_type` | `string` | optional | The repeat's monthly type. |
| `stop_repeat_type` | `string` | optional | The repeat's stop type. |
| `stop_repeat_on_occurrence` | `integer` | optional | The repeat's stop on occurrence. |
| `stop_repeat_on_date` | `datetime` | optional | The repeat's stop on date. |
| `start_date` | `datetime` | optional | The repeat's start date. |
| `end_date` | `datetime` | optional | The repeat's end date. |

**Example:**
```json
{
  "id": 92,
  "repeat_type": "Daily",
  "repeat_frequency": 2,
  "repeat_weekly_days": [],
  "repeat_monthly_type": null,
  "stop_repeat_type": "On Occurrence",
  "stop_repeat_on_occurrence": 10,
  "stop_repeat_on_date": null,
  "start_date": "2021-05-27T00:00:00+00:00",
  "end_date": "2021-06-14T00:00:00+00:00"
}
```

### CustomField

A custom field's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `string` | optional | The custom field's name. |
| `value` | `any` | optional | The custom field's value. |
| `type` | `string` | optional | The custom field's type. |
| `group` | `string` | optional | The custom field's group. |
| `created_at` | `datetime` | optional | The custom field's created date. |
| `updated_at` | `datetime` | optional | The custom field's updated date. |
| `is_required` | `boolean` | optional | The custom field's is required flag. |

**Example:**
```json
[
  {
    "name": "Text",
    "value": "Example text value",
    "type": "text",
    "group": "Default",
    "created_at": "2018-10-11T11:52:33+00:00",
    "updated_at": "2018-10-11T11:52:33+00:00",
    "is_required": true
  }
]
```

### CustomFieldBody

A custom field's body schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `string` | **required** | Used to send the custom field's name that will be set. |
| `value` | `any` | **required** | Used to send the custom field's value that will be set. |

**Example:**
```json
[
  {
    "name": "Text",
    "value": "Example text value"
  },
  {
    "name": "Textarea",
    "value": "Example text area value"
  },
  {
    "name": "Date",
    "value": "2018-10-05"
  },
  {
    "name": "Numeric",
    "value": "157.25"
  },
  {
    "name": "Select",
    "value": "1 one"
  },
  {
    "name": "Checkbox",
    "value": true
  }
]
```

### Customer

A customer's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | The customer's identifier. |
| `customer_name` | `string` | optional | The customer's name. |
| `fully_qualified_name` | `string` | optional | The customer's fully qualified name. |
| `parent_customer` | `string` | optional | The `header` of attached parent customer to the customer (Note: `header` - [string] the parent customer's fields concatenated by pattern `{first_name} {last_name}` with space as separator). |
| `account_number` | `string` | optional | The customer's account number. |
| `account_balance` | `number` | optional | The customer's account balance. |
| `private_notes` | `string` | optional | The customer's private notes. |
| `public_notes` | `string` | optional | The customer's public notes. |
| `credit_rating` | `string` | optional | The customer's credit rating. |
| `labor_charge_type` | `string` | optional | The customer's labor charge type. |
| `labor_charge_default_rate` | `number` | optional | The customer's labor charge default rate. |
| `last_serviced_date` | `datetime` | optional | The customer's last serviced date. |
| `is_bill_for_drive_time` | `boolean` | optional | The customer's is bill for drive time flag. |
| `is_vip` | `boolean` | optional | The customer's is vip flag. |
| `referral_source` | `string` | optional | The `header` of attached referral source to the customer (Note: `header` - [string] the referral source's fields concatenated by pattern `{short_name}`). |
| `agent` | `string` | optional | The `header` of attached agent to the customer (Note: `header` - [string] the agent's fields concatenated by pattern `{first_name} {last_name}` with space as separator). |
| `discount` | `number` | optional | The customer's discount. |
| `discount_type` | `string` | optional | The customer's discount type. |
| `payment_type` | `string` | optional | The `header` of attached payment type to the customer (Note: `header` - [string] the payment type's fields concatenated by pattern `{name}`). |
| `payment_terms` | `string` | optional | The customer's payment terms. |
| `assigned_contract` | `string` | optional | The `header` of attached contract to the customer (Note: `header` - [string] the contract's fields concatenated by pattern `{contract_title}`). |
| `industry` | `string` | optional | The `header` of attached industry to the customer (Note: `header` - [string] the industry's fields concatenated by pattern `{industry}`). |
| `is_taxable` | `boolean` | optional | The customer's is taxable flag. |
| `tax_item_name` | `string` | optional | The `header` of attached tax item to the customer (Note: `header` - [string] the tax item's fields concatenated by pattern `{short_name}` with space as separator). |
| `qbo_sync_token` | `integer` | optional | The customer's qbo sync token. |
| `qbo_currency` | `string` | optional | The customer's qbo currency. |
| `qbo_id` | `integer` | optional | The customer's qbo id. |
| `qbd_id` | `string` | optional | The customer's qbd id. |
| `created_at` | `datetime` | optional | The customer's created date. |
| `updated_at` | `datetime` | optional | The customer's updated date. |
| `contacts` | `array` | optional | The customer's contacts list. |
| `locations` | `array` | optional | The customer's locations list. |
| `custom_fields` | `array` | optional | The customer's custom fields list. |

**Example:**
```json
{
  "id": 1472289,
  "customer_name": "Bob Marley",
  "fully_qualified_name": "Bob Marley",
  "parent_customer": "Jerry Wheeler",
  "account_number": "30000",
  "account_balance": 10.34,
  "private_notes": "None",
  "public_notes": "None",
  "credit_rating": "A+",
  "labor_charge_type": "flat",
  "labor_charge_default_rate": 50.45,
  "last_serviced_date": "2018-08-07",
  "is_bill_for_drive_time": true,
  "is_vip": true,
  "referral_source": "Google AdWords",
  "agent": "John Theowner",
  "discount": 10.23,
  "discount_type": "%",
  "payment_type": "Check",
  "payment_terms": "DUR",
  "assigned_contract": "Retail Service Contract",
  "industry": "Advertising Agencies",
  "is_taxable": false,
  "tax_item_name": "Sanity Tax",
  "qbo_sync_token": 385,
  "qbo_currency": "USD",
  "qbo_id": null,
  "qbd_id": null,
  "created_at": "2018-08-07T18:31:28+00:00",
  "updated_at": "2018-08-07T18:31:28+00:00",
  "contacts": [
    {
      "prefix": "Mr.",
      "fname": "Jerry",
      "lname": "Wheeler",
      "suffix": "suf",
      "contact_type": "Billing",
      "dob": "April 19",
      "anniversary": "October 4",
      "job_title": "Manager",
      "department": "executive",
      "created_at": "2016-12-21T14:12:08+00:00",
      "updated_at": "2016-12-21T14:12:08+00:00",
      "is_primary": true,
      "phones": [
        {
          "phone": "066-361-8172",
          "ext": 38,
          "type": "Mobile",
          "created_at": "2018-10-05T11:51:48+00:00",
          "updated_at": "2018-10-05T11:54:09+00:00",
          "is_mobile": true
        }
      ],
      "emails": [
        {
          "email": "anton.lyubch1@gmail.com",
          "class": "Personal",
          "types_accepted": "CONF,PMT",
          "created_at": "2018-10-05T11:51:48+00:00",
          "updated_at": "2018-10-05T11:54:09+00:00"
        }
      ]
    }
  ],
  "locations": [
    {
      "street_1": "1904 Industrial Blvd",
      "street_2": "103",
      "city": "Colleyville",
      "state_prov": "Texas",
      "postal_code": "76034",
      "country": "USA",
      "nickname": "Office",
      "gate_instructions": "Gate instructions",
      "latitude": 123.45,
      "longitude": 67.89,
      "location_type": "home",
      "created_at": "2018-08-07T18:31:28+00:00",
      "updated_at": "2018-08-07T18:31:28+00:00",
      "is_primary": false,
      "is_gated": false,
      "is_bill_to": false,
      "customer_contact": "Sam Smith"
    }
  ],
  "custom_fields": [
    {
      "name": "Text",
      "value": "Example text value",
      "type": "text",
      "group": "Default",
      "created_at": "2018-10-11T11:52:33+00:00",
      "updated_at": "2018-10-11T11:52:33+00:00",
      "is_required": true
    }
  ]
}
```

### CustomerBody

A customer's body schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `customer_name` | `string` | **required** | Used to send the customer's name that will be set. |
| `parent_customer` | `string` | optional | Used to send a parent customer's `id` or `header` that will be attached to the customer (Note: `id` - [integer] the parent customer's identifier, `header` - [string] the parent customer's fields concatenated by pattern `{customer_name}`). |
| `account_number` | `string` | optional | Used to send the customer's account number that will be set. (default: `If not passed, it takes generated new one.`) |
| `private_notes` | `string` | optional | Used to send the customer's private notes that will be set. |
| `public_notes` | `string` | optional | Used to send the customer's public notes that will be set. |
| `credit_rating` | `string` | optional | Used to send the customer's credit rating that will be set. (default: `If not passed, it takes the value from parent customer (configurable into the company preferences).`) Enum: `A+`, `A`, `B+`, `B`, `C+`, `C`, `U` |
| `labor_charge_type` | `string` | optional | Used to send the customer's labor charge type that will be set. (default: `If not passed, it takes the value from parent customer (configurable into the company preferences).`) Enum: `flat`, `hourly` |
| `labor_charge_default_rate` | `number` | optional | Used to send the customer's labor charge default rate that will be set. (default: `If not passed, it takes the value from parent customer (configurable into the company preferences).`) |
| `last_serviced_date` | `datetime` | optional | Used to send the customer's last serviced date that will be set. |
| `is_bill_for_drive_time` | `boolean` | optional | Used to send the customer's is bill for drive time flag that will be set. (default: `If not passed, it takes the value from parent customer (configurable into the company preferences).`) |
| `is_vip` | `boolean` | optional | Used to send the customer's is vip flag that will be set. (default: `false`) |
| `referral_source` | `string` | optional | Used to send a referral source's `id` or `header` that will be attached to the customer (Note: `id` - [integer] the referral source's identifier, `header` - [string] the referral source's fields concatenated by pattern `{short_name}`). |
| `agent` | `string` | optional | Used to send an agent's `id` or `header` that will be attached to the customer (Note: `id` - [integer] the agent's identifier, `header` - [string] the agent's fields concatenated by pattern `{first_name} {last_name}` with space as separator). |
| `discount` | `number` | optional | Used to send the customer's discount that will be set. (default: `If not passed, it takes the value from parent customer (configurable into the company preferences).`) |
| `discount_type` | `string` | optional | Used to send the customer's discount type that will be set. (default: `If not passed, it takes the value from parent customer (configurable into the company preferences).`) Enum: `$`, `%` |
| `payment_type` | `string` | optional | Used to send a payment type's `id` or `header` that will be attached to the customer (Note: `id` - [integer] the payment type's identifier, `header` - [string] the payment type's fields concatenated by pattern `{name}`). (default: `If not passed, it takes the value from the company preferences or from parent customer (configurable into the company preferences).`) |
| `payment_terms` | `string` | optional | Used to send the customer's payment terms that will be set. (default: `If not passed, it takes the value from the company preferences or from parent customer (configurable into the company preferences).`) |
| `assigned_contract` | `string` | optional | Used to send an assigned contract's `id` or `header` that will be attached to the customer (Note: `id` - [integer] the assigned contract's identifier, `header` - [string] the assigned contract's fields concatenated by pattern `{contract_title}`). |
| `industry` | `string` | optional | Used to send an industry's `id` or `header` that will be attached to the customer (Note: `id` - [integer] the industry's identifier, `header` - [string] the industry's fields concatenated by pattern `{industry}`). |
| `is_taxable` | `boolean` | optional | Used to send the customer's is taxable flag that will be set. (default: `If not passed, it takes the value `true` (configurable into the company preferences).`) |
| `tax_item_name` | `string` | optional | Used to send a tax item's `id` or `header` that will be attached to the customer (Note: `id` - [integer] the tax item's identifier, `header` - [string] the tax item's fields concatenated by pattern `{short_name}`). (default: `If not passed, it takes the value from the company preferences (configurable into the company preferences).`) |
| `qbo_sync_token` | `integer` | optional | Used to send the customer's qbo sync token that will be set. |
| `qbo_currency` | `string` | optional | Used to send the customer's qbo currency that will be set. (default: `If not passed, it takes the value from the company if it was configured, otherwise it takes the value `USD`.`) Enum: `USD`, `CAD`, `JMD`, `THB` |
| `contacts` | `array` | optional | Used to send the customer's contacts list that will be set. (default: `If not passed, it creates the new one.`) |
| `locations` | `array` | optional | Used to send the customer's locations list that will be set. (default: `array`) |
| `custom_fields` | `array` | optional | Used to send the customer's custom fields list that will be set. (default: `If some custom field (configured into the custom fields settings) not passed, it creates the new one with its default value.`) |

**Example:**
```json
{
  "customer_name": "Bob Marley",
  "parent_customer": "Jerry Wheeler",
  "account_number": "30000",
  "private_notes": "None",
  "public_notes": "None",
  "credit_rating": "A+",
  "labor_charge_type": "flat",
  "labor_charge_default_rate": 50.45,
  "last_serviced_date": "2018-08-07",
  "is_bill_for_drive_time": true,
  "is_vip": true,
  "referral_source": "Google AdWords",
  "agent": "John Theowner",
  "discount": 10.23,
  "discount_type": "%",
  "payment_type": "Check",
  "payment_terms": "DUR",
  "assigned_contract": "Retail Service Contract",
  "industry": "Advertising Agencies",
  "is_taxable": false,
  "tax_item_name": "Sanity Tax",
  "qbo_sync_token": 385,
  "qbo_currency": "USD",
  "contacts": [
    {
      "prefix": "Mr.",
      "fname": "Jerry",
      "lname": "Wheeler",
      "suffix": "suf",
      "contact_type": "Billing",
      "dob": "April 19",
      "anniversary": "October 4",
      "job_title": "Manager",
      "department": "executive",
      "is_primary": true,
      "phones": [
        {
          "phone": "066-361-8172",
          "ext": 38,
          "type": "Mobile"
        }
      ],
      "emails": [
        {
          "email": "anton.lyubch1@gmail.com",
          "class": "Personal",
          "types_accepted": "CONF,PMT"
        }
      ]
    }
  ],
  "locations": [
    {
      "street_1": "1904 Industrial Blvd",
      "street_2": "103",
      "city": "Colleyville",
      "state_prov": "Texas",
      "postal_code": "76034",
      "country": "USA",
      "nickname": "Office",
      "gate_instructions": "Gate instructions",
      "latitude": "123.45",
      "longitude": "67.89",
      "location_type": "home",
      "is_primary": false,
      "is_gated": false,
      "is_bill_to": false,
      "customer_contact": "Sam Smith"
    }
  ],
  "custom_fields": [
    {
      "name": "Text",
      "value": "Example text value"
    },
    {
      "name": "Textarea",
      "value": "Example text area value"
    },
    {
      "name": "Date",
      "value": "2018-10-05"
    },
    {
      "name": "Numeric",
      "value": "157.25"
    },
    {
      "name": "Select",
      "value": "1 one"
    },
    {
      "name": "Checkbox",
      "value": true
    }
  ]
}
```

### CustomerView

A customer's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | The customer's identifier. |
| `customer_name` | `string` | optional | The customer's name. |
| `fully_qualified_name` | `string` | optional | The customer's fully qualified name. |
| `parent_customer` | `string` | optional | The `header` of attached parent customer to the customer (Note: `header` - [string] the parent customer's fields concatenated by pattern `{first_name} {last_name}` with space as separator). |
| `account_number` | `string` | optional | The customer's account number. |
| `account_balance` | `number` | optional | The customer's account balance. |
| `private_notes` | `string` | optional | The customer's private notes. |
| `public_notes` | `string` | optional | The customer's public notes. |
| `credit_rating` | `string` | optional | The customer's credit rating. |
| `labor_charge_type` | `string` | optional | The customer's labor charge type. |
| `labor_charge_default_rate` | `number` | optional | The customer's labor charge default rate. |
| `last_serviced_date` | `datetime` | optional | The customer's last serviced date. |
| `is_bill_for_drive_time` | `boolean` | optional | The customer's is bill for drive time flag. |
| `is_vip` | `boolean` | optional | The customer's is vip flag. |
| `referral_source` | `string` | optional | The `header` of attached referral source to the customer (Note: `header` - [string] the referral source's fields concatenated by pattern `{short_name}`). |
| `agent` | `string` | optional | The `header` of attached agent to the customer (Note: `header` - [string] the agent's fields concatenated by pattern `{first_name} {last_name}` with space as separator). |
| `discount` | `number` | optional | The customer's discount. |
| `discount_type` | `string` | optional | The customer's discount type. |
| `payment_type` | `string` | optional | The `header` of attached payment type to the customer (Note: `header` - [string] the payment type's fields concatenated by pattern `{name}`). |
| `payment_terms` | `string` | optional | The customer's payment terms. |
| `assigned_contract` | `string` | optional | The `header` of attached contract to the customer (Note: `header` - [string] the contract's fields concatenated by pattern `{contract_title}`). |
| `industry` | `string` | optional | The `header` of attached industry to the customer (Note: `header` - [string] the industry's fields concatenated by pattern `{industry}`). |
| `is_taxable` | `boolean` | optional | The customer's is taxable flag. |
| `tax_item_name` | `string` | optional | The `header` of attached tax item to the customer (Note: `header` - [string] the tax item's fields concatenated by pattern `{short_name}` with space as separator). |
| `qbo_sync_token` | `integer` | optional | The customer's qbo sync token. |
| `qbo_currency` | `string` | optional | The customer's qbo currency. |
| `qbo_id` | `integer` | optional | The customer's qbo id. |
| `qbd_id` | `string` | optional | The customer's qbd id. |
| `created_at` | `datetime` | optional | The customer's created date. |
| `updated_at` | `datetime` | optional | The customer's updated date. |
| `contacts` | `array` | optional | The customer's contacts list. |
| `locations` | `array` | optional | The customer's locations list. |
| `custom_fields` | `array` | optional | The customer's custom fields list. |
| `_expandable` | `array` | **required** | The extra-field's list that are not expanded and can be expanded into objects. |

**Example:**
```json
{
  "id": 1472289,
  "customer_name": "Bob Marley",
  "fully_qualified_name": "Bob Marley",
  "parent_customer": "Jerry Wheeler",
  "account_number": "30000",
  "account_balance": 10.34,
  "private_notes": "None",
  "public_notes": "None",
  "credit_rating": "A+",
  "labor_charge_type": "flat",
  "labor_charge_default_rate": 50.45,
  "last_serviced_date": "2018-08-07",
  "is_bill_for_drive_time": true,
  "is_vip": true,
  "referral_source": "Google AdWords",
  "agent": "John Theowner",
  "discount": 10.23,
  "discount_type": "%",
  "payment_type": "Check",
  "payment_terms": "DUR",
  "assigned_contract": "Retail Service Contract",
  "industry": "Advertising Agencies",
  "is_taxable": false,
  "tax_item_name": "Sanity Tax",
  "qbo_sync_token": 385,
  "qbo_currency": "USD",
  "qbo_id": null,
  "qbd_id": null,
  "created_at": "2018-08-07T18:31:28+00:00",
  "updated_at": "2018-08-07T18:31:28+00:00",
  "contacts": [
    {
      "prefix": "Mr.",
      "fname": "Jerry",
      "lname": "Wheeler",
      "suffix": "suf",
      "contact_type": "Billing",
      "dob": "April 19",
      "anniversary": "October 4",
      "job_title": "Manager",
      "department": "executive",
      "created_at": "2016-12-21T14:12:08+00:00",
      "updated_at": "2016-12-21T14:12:08+00:00",
      "is_primary": true,
      "phones": [
        {
          "phone": "066-361-8172",
          "ext": 38,
          "type": "Mobile",
          "created_at": "2018-10-05T11:51:48+00:00",
          "updated_at": "2018-10-05T11:54:09+00:00",
          "is_mobile": true
        }
      ],
      "emails": [
        {
          "email": "anton.lyubch1@gmail.com",
          "class": "Personal",
          "types_accepted": "CONF,PMT",
          "created_at": "2018-10-05T11:51:48+00:00",
          "updated_at": "2018-10-05T11:54:09+00:00"
        }
      ]
    }
  ],
  "locations": [
    {
      "street_1": "1904 Industrial Blvd",
      "street_2": "103",
      "city": "Colleyville",
      "state_prov": "Texas",
      "postal_code": "76034",
      "country": "USA",
      "nickname": "Office",
      "gate_instructions": "Gate instructions",
      "latitude": 123.45,
      "longitude": 67.89,
      "location_type": "home",
      "created_at": "2018-08-07T18:31:28+00:00",
      "updated_at": "2018-08-07T18:31:28+00:00",
      "is_primary": false,
      "is_gated": false,
      "is_bill_to": false,
      "customer_contact": "Sam Smith"
    }
  ],
  "custom_fields": [
    {
      "name": "Text",
      "value": "Example text value",
      "type": "text",
      "group": "Default",
      "created_at": "2018-10-11T11:52:33+00:00",
      "updated_at": "2018-10-11T11:52:33+00:00",
      "is_required": true
    }
  ],
  "_expandable": [
    "contacts",
    "contacts.phones",
    "contacts.emails",
    "locations",
    "custom_fields"
  ]
}
```

### CustomerContact

A customer contact's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `prefix` | `string` | optional | The contact's prefix. |
| `fname` | `string` | optional | The contact's first name. |
| `lname` | `string` | optional | The contact's last name. |
| `suffix` | `string` | optional | The contact's suffix. |
| `contact_type` | `string` | optional | The contact's type. |
| `dob` | `string` | optional | The contact's dob. |
| `anniversary` | `string` | optional | The contact's anniversary. |
| `job_title` | `string` | optional | The contact's job title. |
| `department` | `string` | optional | The contact's department. |
| `created_at` | `datetime` | optional | The contact's created date. |
| `updated_at` | `datetime` | optional | The contact's updated date. |
| `is_primary` | `boolean` | optional | The contact's is primary flag. |
| `phones` | `array` | optional | The contact's phones list. |
| `emails` | `array` | optional | The contact's emails list. |

**Example:**
```json
[
  {
    "prefix": "Mr.",
    "fname": "Jerry",
    "lname": "Wheeler",
    "suffix": "suf",
    "contact_type": "Billing",
    "dob": "April 19",
    "anniversary": "October 4",
    "job_title": "Manager",
    "department": "executive",
    "created_at": "2016-12-21T14:12:08+00:00",
    "updated_at": "2016-12-21T14:12:08+00:00",
    "is_primary": true,
    "phones": [
      {
        "phone": "066-361-8172",
        "ext": 38,
        "type": "Mobile",
        "created_at": "2018-10-05T11:51:48+00:00",
        "updated_at": "2018-10-05T11:54:09+00:00",
        "is_mobile": true
      }
    ],
    "emails": [
      {
        "email": "anton.lyubch1@gmail.com",
        "class": "Personal",
        "types_accepted": "CONF,PMT",
        "created_at": "2018-10-05T11:51:48+00:00",
        "updated_at": "2018-10-05T11:54:09+00:00"
      }
    ]
  }
]
```

### CustomerContactBody

A customer contact's body schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `prefix` | `string` | optional | Used to send the contact's prefix that will be set. Enum: `Mr.`, `Mrs.`, `Ms.`, `Dr.`, `Atty.`, `Prof.`, `Hon.`, `Gov.`, `Ofc.`, `Rep.`, `Sen.`, `Amb.`, `Sec.`, `Pvt.`, `Cpl.`, `Sgt.`, `Adm.`, `Gen.`, `Maj.`, `Capt.`, `Cmdr.`, `Lt.`, `Lt Col.`, `Col.` |
| `fname` | `string` | **required** | Used to send the contact's first name that will be set. |
| `lname` | `string` | **required** | Used to send the contact's last name that will be set. |
| `suffix` | `string` | optional | Used to send the contact's suffix that will be set. |
| `contact_type` | `string` | optional | Used to send the contact's type that will be set. |
| `dob` | `string` | optional | Used to send the contact's dob that will be set. |
| `anniversary` | `string` | optional | Used to send the contact's anniversary that will be set. |
| `job_title` | `string` | optional | Used to send the contact's job title that will be set. |
| `department` | `string` | optional | Used to send the contact's department that will be set. |
| `is_primary` | `boolean` | optional | Used to send the contact's is primary flag that will be set. When it is passed as `true`, then the customer's existing primary contact (if any) will become secondary, and this one will become the primary one. (default: `If not passed and the customer does not have primary contact, it takes the value `true`, else if the customer already have primary contact, it takes the value `false`.`) |
| `phones` | `array` | optional | Used to send the contact's phones list that will be set. (default: `array`) |
| `emails` | `array` | optional | Used to send the contact's emails list that will be set. (default: `array`) |

**Example:**
```json
[
  {
    "prefix": "Mr.",
    "fname": "Jerry",
    "lname": "Wheeler",
    "suffix": "suf",
    "contact_type": "Billing",
    "dob": "April 19",
    "anniversary": "October 4",
    "job_title": "Manager",
    "department": "executive",
    "is_primary": true,
    "phones": [
      {
        "phone": "066-361-8172",
        "ext": 38,
        "type": "Mobile"
      }
    ],
    "emails": [
      {
        "email": "anton.lyubch1@gmail.com",
        "class": "Personal",
        "types_accepted": "CONF,PMT"
      }
    ]
  }
]
```

### CustomerEmail

A customer email's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `email` | `string` | optional | The email's address. |
| `class` | `string` | optional | The email's class. |
| `types_accepted` | `string` | optional | The email's types accepted. |
| `created_at` | `datetime` | optional | The email's created date. |
| `updated_at` | `datetime` | optional | The email's updated date. |

**Example:**
```json
[
  {
    "email": "anton.lyubch1@gmail.com",
    "class": "Personal",
    "types_accepted": "CONF,PMT",
    "created_at": "2018-10-05T11:51:48+00:00",
    "updated_at": "2018-10-05T11:54:09+00:00"
  }
]
```

### CustomerEmailBody

A customer email's body schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `email` | `string` | **required** | Used to send the email's address that will be set. |
| `class` | `string` | optional | Used to send the email's class that will be set. Enum: `Personal`, `Business`, `Other` |
| `types_accepted` | `string` | optional | Used to send the email's types accepted that will be set. Accepted value is comma-separated string. Enum: `CONF`, `STATUS`, `PMT`, `INV` |

**Example:**
```json
[
  {
    "email": "anton.lyubch1@gmail.com",
    "class": "Personal",
    "types_accepted": "CONF,PMT"
  }
]
```

### CustomerLocation

A customer location's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `street_1` | `string` | optional | The location's street 1. |
| `street_2` | `string` | optional | The location's street 2. |
| `city` | `string` | optional | The location's city. |
| `state_prov` | `string` | optional | The location's state. |
| `postal_code` | `string` | optional | The location's postal code. |
| `country` | `string` | optional | The location's country. |
| `nickname` | `string` | optional | The location's nickname. |
| `gate_instructions` | `string` | optional | The location's gate instructions. |
| `latitude` | `number` | optional | The location's latitude. |
| `longitude` | `number` | optional | The location's longitude. |
| `location_type` | `string` | optional | The location's type. |
| `created_at` | `datetime` | optional | The location's created date. |
| `updated_at` | `datetime` | optional | The location's updated date. |
| `is_primary` | `boolean` | optional | The location's is primary flag. |
| `is_gated` | `boolean` | optional | The location's is gated flag. |
| `is_bill_to` | `boolean` | optional | The location's is bill to flag. |
| `customer_contact` | `string` | optional | The `header` of attached customer contact to the location (Note: `header` - [string] the customer contact's fields concatenated by pattern `{fname} {lname}` with space as separator). |

**Example:**
```json
[
  {
    "street_1": "1904 Industrial Blvd",
    "street_2": "103",
    "city": "Colleyville",
    "state_prov": "Texas",
    "postal_code": "76034",
    "country": "USA",
    "nickname": "Office",
    "gate_instructions": "Gate instructions",
    "latitude": 123.45,
    "longitude": 67.89,
    "location_type": "home",
    "created_at": "2018-08-07T18:31:28+00:00",
    "updated_at": "2018-08-07T18:31:28+00:00",
    "is_primary": false,
    "is_gated": false,
    "is_bill_to": false,
    "customer_contact": "Sam Smith"
  }
]
```

### CustomerLocationBody

A customer location's body schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `street_1` | `string` | **required** | Used to send the location's street 1 that will be set. |
| `street_2` | `string` | optional | Used to send the location's street 2 that will be set. |
| `city` | `string` | optional | Used to send the location's city that will be set. |
| `state_prov` | `string` | optional | Used to send the location's state that will be set. |
| `postal_code` | `string` | optional | Used to send the location's postal code that will be set. |
| `country` | `string` | optional | Used to send the location's country that will be set. |
| `nickname` | `string` | optional | Used to send the location's nickname that will be set. |
| `gate_instructions` | `string` | optional | Used to send the location's gate instructions that will be set. |
| `latitude` | `number` | optional | Used to send the location's latitude that will be set. (default: `0`) |
| `longitude` | `number` | optional | Used to send the location's longitude that will be set. (default: `0`) |
| `location_type` | `string` | optional | Used to send the location's type that will be set. |
| `is_primary` | `boolean` | optional | Used to send the location's is primary flag that will be set. When it is passed as `true`, then the customer's existing primary location (if any) will become secondary, and this one will become the primary one. (default: `If not passed and the customer does not have primary location, it takes the value `true`, else if the customer already have primary location, it takes the value `false`.`) |
| `is_gated` | `boolean` | optional | Used to send the location's `is gated` flag that will be set. (default: `false`) |
| `is_bill_to` | `boolean` | optional | Used to send the location's is bill to flag that will be set. (default: `false`) |
| `customer_contact` | `string` | optional | Used to send a customer contact's `id` or `header` that will be attached to the location (Note: `id` - [integer] the customer contact's identifier, `header` - [string] the customer contact's fields concatenated by pattern `{fname} {lname}` with space as separator). |

**Example:**
```json
[
  {
    "street_1": "1904 Industrial Blvd",
    "street_2": "103",
    "city": "Colleyville",
    "state_prov": "Texas",
    "postal_code": "76034",
    "country": "USA",
    "nickname": "Office",
    "gate_instructions": "Gate instructions",
    "latitude": "123.45",
    "longitude": "67.89",
    "location_type": "home",
    "is_primary": false,
    "is_gated": false,
    "is_bill_to": false,
    "customer_contact": "Sam Smith"
  }
]
```

### CustomerPhone

A customer phone's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `phone` | `string` | optional | The phone's number. |
| `ext` | `integer` | optional | The phone's extension. |
| `type` | `string` | optional | The phone's type. |
| `created_at` | `datetime` | optional | The phone's created date. |
| `updated_at` | `datetime` | optional | The phone's updated date. |
| `is_mobile` | `boolean` | optional | The phone's is mobile flag. |

**Example:**
```json
[
  {
    "phone": "066-361-8172",
    "ext": 38,
    "type": "Mobile",
    "created_at": "2018-10-05T11:51:48+00:00",
    "updated_at": "2018-10-05T11:54:09+00:00",
    "is_mobile": true
  }
]
```

### CustomerPhoneBody

A customer phone's body schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `phone` | `string` | **required** | Used to send the phone's number that will be set. |
| `ext` | `integer` | optional | Used to send the phone's extension that will be set. |
| `type` | `string` | optional | Used to send the phone's type that will be set. Enum: `Mobile`, `Home`, `Work`, `Other` |

**Example:**
```json
[
  {
    "phone": "066-361-8172",
    "ext": 38,
    "type": "Mobile"
  }
]
```

### Equipment

An equipment's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | The equipment's identifier. |
| `type` | `string` | optional | The equipment's type. |
| `make` | `string` | optional | The equipment's make. |
| `model` | `string` | optional | The equipment's model. |
| `sku` | `string` | optional | The equipment's sku. |
| `serial_number` | `string` | optional | The equipment's serial number. |
| `location` | `string` | optional | The equipment's location. |
| `notes` | `string` | optional | The equipment's notes. |
| `extended_warranty_provider` | `string` | optional | The equipment's extended warranty provider. |
| `is_extended_warranty` | `boolean` | optional | The equipment's is extended warranty flag. |
| `extended_warranty_date` | `datetime` | optional | The equipment's extended warranty date. |
| `warranty_date` | `datetime` | optional | The equipment's warranty date. |
| `install_date` | `datetime` | optional | The equipment's install date. |
| `created_at` | `datetime` | optional | The equipment's created date. |
| `updated_at` | `datetime` | optional | The equipment's updated date. |
| `customer_id` | `integer` | optional | The `id` of attached customer to the equipment (Note: `id` - [integer] the customer's identifier). |
| `customer` | `string` | optional | The `header` of attached customer to the equipment (Note: `header` - [string] the customer's fields concatenated by pattern `{customer_name}`). |
| `customer_location` | `string` | optional | The `header` of attached customer location to the equipment (Note: `header` - [string] the customer location's fields concatenated by pattern `{nickname} {street_1} {city}` with space as separator). |
| `custom_fields` | `array` | optional | The equipment's custom fields list. |

**Example:**
```json
{
  "id": 12,
  "type": "Test Equipment",
  "make": "New Test Manufacturer",
  "model": "TST1231MOD",
  "sku": "SK15432",
  "serial_number": "1231#SRN",
  "location": "Test Location",
  "notes": "Test notes for the Test Equipment",
  "extended_warranty_provider": "Test War Provider",
  "is_extended_warranty": false,
  "extended_warranty_date": "2015-02-17",
  "warranty_date": "2015-01-16",
  "install_date": "2014-12-15",
  "created_at": "2015-01-16T11:31:49+00:00",
  "updated_at": "2015-01-16T11:31:49+00:00",
  "customer_id": 87,
  "customer": "John Theowner",
  "customer_location": "Office",
  "custom_fields": [
    {
      "name": "Text",
      "value": "Example text value",
      "type": "text",
      "group": "Default",
      "created_at": "2018-10-11T11:52:33+00:00",
      "updated_at": "2018-10-11T11:52:33+00:00",
      "is_required": true
    }
  ]
}
```

### EquipmentBody

An equipment's body schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `string` | optional | Used to send the equipment's identifier that will be searched. You may pass this parameter if you do not want to create new entry but assign existing one. You may assign by `identifier` or `header` (Note: `identifier` - [integer] the equipment's identifier, `header` - [string] the equipment's fields concatenated by pattern `{type}:{make}:{model}:{serial_number}` with colon as separator). (default: `If not passed, it creates new one.`) |
| `type` | `string` | optional | Used to send the equipment's type that will be set. |
| `make` | `string` | optional | Used to send the equipment's make that will be set. |
| `model` | `string` | optional | Used to send the equipment's model that will be set. |
| `sku` | `string` | optional | Used to send the equipment's sku that will be set. |
| `serial_number` | `string` | optional | Used to send the equipment's serial number that will be set. |
| `location` | `string` | optional | Used to send the equipment's location that will be set. |
| `notes` | `string` | optional | Used to send the equipment's notes that will be set. |
| `extended_warranty_provider` | `string` | optional | Used to send the equipment's extended warranty provider that will be set. |
| `is_extended_warranty` | `boolean` | optional | Used to send the equipment's is extended warranty flag that will be set. (default: `false`) |
| `extended_warranty_date` | `datetime` | optional | Used to send the equipment's extended warranty date that will be set. |
| `warranty_date` | `datetime` | optional | Used to send the equipment's warranty date that will be set. |
| `install_date` | `datetime` | optional | Used to send the equipment's install date that will be set. |
| `customer_location` | `string` | optional | Used to send a customer location's `id` or `header` that will be attached to the equipment (Note: `id` - [integer] the customer location's identifier, `header` - [string] the customer location's fields concatenated by pattern `{nickname} {street_1} {city}` with space as separator). |
| `custom_fields` | `array` | optional | Used to send the equipment's custom fields list that will be set. (default: `If some custom field (configured into the custom fields settings) not passed, it creates the new one with its default value.`) |

**Example:**
```json
{
  "id": "COIL:ABUS:LMU-2620i:445577998871",
  "type": "Test Equipment",
  "make": "New Test Manufacturer",
  "model": "TST1231MOD",
  "sku": "SK15432",
  "serial_number": "1231#SRN",
  "location": "Test Location",
  "notes": "Test notes for the Test Equipment",
  "extended_warranty_provider": "Test War Provider",
  "is_extended_warranty": false,
  "extended_warranty_date": "2015-02-17",
  "warranty_date": "2015-01-16",
  "install_date": "2014-12-15",
  "customer_location": "Office",
  "custom_fields": [
    {
      "name": "Text",
      "value": "Example text value"
    },
    {
      "name": "Textarea",
      "value": "Example text area value"
    },
    {
      "name": "Date",
      "value": "2018-10-05"
    },
    {
      "name": "Numeric",
      "value": "157.25"
    },
    {
      "name": "Select",
      "value": "1 one"
    },
    {
      "name": "Checkbox",
      "value": true
    }
  ]
}
```

### EquipmentView

An equipment's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | The equipment's identifier. |
| `type` | `string` | optional | The equipment's type. |
| `make` | `string` | optional | The equipment's make. |
| `model` | `string` | optional | The equipment's model. |
| `sku` | `string` | optional | The equipment's sku. |
| `serial_number` | `string` | optional | The equipment's serial number. |
| `location` | `string` | optional | The equipment's location. |
| `notes` | `string` | optional | The equipment's notes. |
| `extended_warranty_provider` | `string` | optional | The equipment's extended warranty provider. |
| `is_extended_warranty` | `boolean` | optional | The equipment's is extended warranty flag. |
| `extended_warranty_date` | `datetime` | optional | The equipment's extended warranty date. |
| `warranty_date` | `datetime` | optional | The equipment's warranty date. |
| `install_date` | `datetime` | optional | The equipment's install date. |
| `created_at` | `datetime` | optional | The equipment's created date. |
| `updated_at` | `datetime` | optional | The equipment's updated date. |
| `customer_id` | `integer` | optional | The `id` of attached customer to the equipment (Note: `id` - [integer] the customer's identifier). |
| `customer` | `string` | optional | The `header` of attached customer to the equipment (Note: `header` - [string] the customer's fields concatenated by pattern `{customer_name}`). |
| `customer_location` | `string` | optional | The `header` of attached customer location to the equipment (Note: `header` - [string] the customer location's fields concatenated by pattern `{nickname} {street_1} {city}` with space as separator). |
| `custom_fields` | `array` | optional | The equipment's custom fields list. |
| `_expandable` | `array` | **required** | The extra-field's list that are not expanded and can be expanded into objects. |

**Example:**
```json
{
  "id": 12,
  "type": "Test Equipment",
  "make": "New Test Manufacturer",
  "model": "TST1231MOD",
  "sku": "SK15432",
  "serial_number": "1231#SRN",
  "location": "Test Location",
  "notes": "Test notes for the Test Equipment",
  "extended_warranty_provider": "Test War Provider",
  "is_extended_warranty": false,
  "extended_warranty_date": "2015-02-17",
  "warranty_date": "2015-01-16",
  "install_date": "2014-12-15",
  "created_at": "2015-01-16T11:31:49+00:00",
  "updated_at": "2015-01-16T11:31:49+00:00",
  "customer_id": 87,
  "customer": "John Theowner",
  "customer_location": "Office",
  "custom_fields": [
    {
      "name": "Text",
      "value": "Example text value",
      "type": "text",
      "group": "Default",
      "created_at": "2018-10-11T11:52:33+00:00",
      "updated_at": "2018-10-11T11:52:33+00:00",
      "is_required": true
    }
  ],
  "_expandable": [
    "custom_fields"
  ]
}
```

### Estimate

An estimate's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | The estimate's identifier. |
| `number` | `string` | optional | The estimate's number. |
| `description` | `string` | optional | The estimate's description. |
| `tech_notes` | `string` | optional | The estimate's tech notes. |
| `customer_payment_terms` | `string` | optional | The estimate's customer payment terms. |
| `payment_status` | `string` | optional | The estimate's payment status. |
| `taxes_fees_total` | `number` | optional | The estimate's taxes and fees total. |
| `total` | `number` | optional | The estimate's total. |
| `due_total` | `number` | optional | The estimate's due total. |
| `cost_total` | `number` | optional | The estimate's cost total. |
| `duration` | `integer` | optional | The estimate's duration (in seconds). |
| `time_frame_promised_start` | `string` | optional | The estimate's time frame promised start. |
| `time_frame_promised_end` | `string` | optional | The estimate's time frame promised end. |
| `start_date` | `datetime` | optional | The estimate's start date. |
| `created_at` | `datetime` | optional | The estimate's created date. |
| `updated_at` | `datetime` | optional | The estimate's updated date. |
| `customer_id` | `integer` | optional | The `id` of attached customer to the estimate (Note: `id` - [integer] the customer's identifier). |
| `customer_name` | `string` | optional | The `header` of attached customer to the estimate (Note: `header` - [string] the customer's fields concatenated by pattern `{customer_name}`). |
| `parent_customer` | `string` | optional | The `header` of attached parent customer to the estimate (Note: `header` - [string] the parent customer's fields concatenated by pattern `{customer_name}`). |
| `status` | `string` | optional | The `header` of attached status to the estimate (Note: `header` - [string] the status'es fields concatenated by pattern `{name}`). |
| `sub_status` | `string` | optional | The `header` of attached sub status to the estimate (Note: `header` - [string] the sub status's fields concatenated by pattern `{name}`). |
| `contact_first_name` | `string` | optional | The estimate's contact first name. |
| `contact_last_name` | `string` | optional | The estimate's contact last name. |
| `street_1` | `string` | optional | The estimate's location street 1. |
| `street_2` | `string` | optional | The estimate's location street 2. |
| `city` | `string` | optional | The estimate's location city. |
| `state_prov` | `string` | optional | The estimate's location state prov. |
| `postal_code` | `string` | optional | The estimate's location postal code. |
| `location_name` | `string` | optional | The estimate's location name. |
| `is_gated` | `boolean` | optional | The estimate's location is gated flag. |
| `gate_instructions` | `string` | optional | The estimate's location gate instructions. |
| `category` | `string` | optional | The `header` of attached category to the estimate (Note: `header` - [string] the category's fields concatenated by pattern `{category}`). |
| `source` | `string` | optional | The `header` of attached source to the estimate (Note: `header` - [string] the source's fields concatenated by pattern `{short_name}`). |
| `payment_type` | `string` | optional | The `header` of attached payment type to the estimate (Note: `header` - [string] the payment type's fields concatenated by pattern `{short_name}`). |
| `project` | `string` | optional | The `header` of attached project to the estimate (Note: `header` - [string] the project's fields concatenated by pattern `{name}`). |
| `phase` | `string` | optional | The `header` of attached phase to the estimate (Note: `header` - [string] the phase's fields concatenated by pattern `{name}`). |
| `po_number` | `string` | optional | The estimate's po number. |
| `contract` | `string` | optional | The `header` of attached contract to the estimate (Note: `header` - [string] the contract's fields concatenated by pattern `{contract_title}`). |
| `note_to_customer` | `string` | optional | The estimate's note to customer. |
| `opportunity_rating` | `integer` | optional | The estimate's opportunity rating. |
| `opportunity_owner` | `string` | optional | The `header` of attached opportunity owner to the estimate (Note: `header` - [string] the opportunity owner's fields concatenated by pattern `{first_name} {last_name}` with space as separator). |
| `agents` | `array` | optional | The estimate's agents list. |
| `custom_fields` | `array` | optional | The estimate's custom fields list. |
| `pictures` | `array` | optional | The estimate's pictures list. |
| `documents` | `array` | optional | The estimate's documents list. |
| `equipment` | `array` | optional | The estimate's equipments list. |
| `techs_assigned` | `array` | optional | The estimate's techs assigned list. |
| `tasks` | `array` | optional | The estimate's tasks list. |
| `notes` | `array` | optional | The estimate's notes list. |
| `products` | `array` | optional | The estimate's products list. |
| `services` | `array` | optional | The estimate's services list. |
| `other_charges` | `array` | optional | The estimate's other charges list. |
| `payments` | `array` | optional | The estimate's payments list. |
| `signatures` | `array` | optional | The estimate's signatures list. |
| `printable_work_order` | `array` | optional | The estimate's printable work order list. |
| `tags` | `array` | optional | The estimate's tags list. |

**Example:**
```json
{
  "id": 13,
  "number": "1152157",
  "description": "This is a test",
  "tech_notes": "You guys know what to do.",
  "customer_payment_terms": "COD",
  "payment_status": "Unpaid",
  "taxes_fees_total": 193.25,
  "total": 193,
  "due_total": 193,
  "cost_total": 0,
  "duration": 3600,
  "time_frame_promised_start": "14:10",
  "time_frame_promised_end": "14:10",
  "start_date": "2015-01-08",
  "created_at": "2014-09-08T20:42:04+00:00",
  "updated_at": "2016-01-07T17:20:36+00:00",
  "customer_id": 11,
  "customer_name": "Max Paltsev",
  "parent_customer": "Jerry Wheeler",
  "status": "Cancelled",
  "sub_status": "job1",
  "contact_first_name": "Sam",
  "contact_last_name": "Smith",
  "street_1": "1904 Industrial Blvd",
  "street_2": "103",
  "city": "Colleyville",
  "state_prov": "Texas",
  "postal_code": "76034",
  "location_name": "Office",
  "is_gated": false,
  "gate_instructions": null,
  "category": "Quick Home Energy Check-ups",
  "source": "Yellow Pages",
  "payment_type": "Direct Bill",
  "project": "reshma",
  "phase": "Closeup",
  "po_number": "86305",
  "contract": "Retail Service Contract",
  "note_to_customer": "Sample Note To Customer.",
  "opportunity_rating": 4,
  "opportunity_owner": "John Theowner",
  "agents": [
    {
      "id": 31,
      "first_name": "Justin",
      "last_name": "Wormell"
    },
    {
      "id": 32,
      "first_name": "John",
      "last_name": "Theowner"
    }
  ],
  "custom_fields": [
    {
      "name": "Text",
      "value": "Example text value",
      "type": "text",
      "group": "Default",
      "created_at": "2018-10-11T11:52:33+00:00",
      "updated_at": "2018-10-11T11:52:33+00:00",
      "is_required": true
    }
  ],
  "pictures": [
    {
      "name": "1442951633_images.jpeg",
      "file_location": "1442951633_images.jpeg",
      "doc_type": "IMG",
      "comment": null,
      "sort": 2,
      "is_private": false,
      "created_at": "2015-09-22T19:53:53+00:00",
      "updated_at": "2015-09-22T19:53:53+00:00",
      "customer_doc_id": 992
    }
  ],
  "documents": [
    {
      "name": "test1John.pdf",
      "file_location": "1421408539_test1John.pdf",
      "doc_type": "DOC",
      "comment": null,
      "sort": 1,
      "is_private": false,
      "created_at": "2015-01-16T11:42:19+00:00",
      "updated_at": "2018-08-21T08:21:14+00:00",
      "customer_doc_id": 998
    }
  ],
  "equipment": [
    {
      "id": 12,
      "type": "Test Equipment",
      "make": "New Test Manufacturer",
      "model": "TST1231MOD",
      "sku": "SK15432",
      "serial_number": "1231#SRN",
      "location": "Test Location",
      "notes": "Test notes for the Test Equipment",
      "extended_warranty_provider": "Test War Provider",
      "is_extended_warranty": false,
      "extended_warranty_date": "2015-02-17",
      "warranty_date": "2015-01-16",
      "install_date": "2014-12-15",
      "created_at": "2015-01-16T11:31:49+00:00",
      "updated_at": "2015-01-16T11:31:49+00:00",
      "customer_id": 87,
      "customer": "John Theowner",
      "customer_location": "Office",
      "custom_fields": [
        {
          "name": "Text",
          "value": "Example text value",
          "type": "text",
          "group": "Default",
          "created_at": "2018-10-11T11:52:33+00:00",
          "updated_at": "2018-10-11T11:52:33+00:00",
          "is_required": true
        }
      ]
    }
  ],
  "techs_assigned": [
    {
      "id": 31,
      "first_name": "Justin",
      "last_name": "Wormell"
    },
    {
      "id": 32,
      "first_name": "John",
      "last_name": "Theowner"
    }
  ],
  "tasks": [
    {
      "type": "Misc",
      "description": "x",
      "start_time": null,
      "start_date": null,
      "end_date": null,
      "is_completed": false,
      "created_at": "2017-03-20T10:48:38+00:00",
      "updated_at": "2017-03-20T10:48:38+00:00"
    }
  ],
  "notes": [
    {
      "notes": "SHOULD BE DELIVERED TO US 6/1/15 AND RICHARD NEEDS TO PAINT",
      "created_at": "2015-05-27T16:32:06+00:00",
      "updated_at": "2015-05-27T16:32:06+00:00"
    }
  ],
  "products": [
    {
      "name": "1755LFB",
      "description": "Finishing Trim Kit - 1\" - Black\r\nModel: \r\nSKU: \r\nType: \r\nPart Number: ",
      "multiplier": 3,
      "rate": 459,
      "total": 1377,
      "cost": 0,
      "actual_cost": 0,
      "item_index": 0,
      "parent_index": 0,
      "created_at": "2015-08-20T09:08:36+00:00",
      "updated_at": "2015-11-19T20:38:07+00:00",
      "is_show_rate_items": true,
      "tax": "City Tax",
      "product": "1755LFB",
      "product_list_id": 45302,
      "warehouse_id": 200,
      "pattern_row_id": null,
      "qbo_class_id": null,
      "qbd_class_id": null
    }
  ],
  "services": [
    {
      "name": "Service Call Fee",
      "description": null,
      "multiplier": 1,
      "rate": 33.15,
      "total": 121,
      "cost": 121,
      "actual_cost": 121,
      "item_index": 3,
      "parent_index": 0,
      "created_at": "2015-08-20T09:08:36+00:00",
      "updated_at": "2015-11-19T20:38:07+00:00",
      "is_show_rate_items": true,
      "tax": "City Tax",
      "service": "Nabeeel",
      "service_list_id": 45302,
      "service_rate_id": 200,
      "pattern_row_id": null,
      "qbo_class_id": null,
      "qbd_class_id": null
    }
  ],
  "other_charges": [
    {
      "name": "fee1",
      "rate": 5.15,
      "total": 14.3,
      "charge_index": 1,
      "parent_index": 1,
      "is_percentage": true,
      "is_discount": false,
      "created_at": "2015-08-20T09:08:52+00:00",
      "updated_at": "2015-11-19T20:38:07+00:00",
      "other_charge": "fee1",
      "applies_to": null,
      "service_list_id": null,
      "other_charge_id": 248,
      "pattern_row_id": null,
      "qbo_class_id": null,
      "qbd_class_id": null
    }
  ],
  "payments": [
    {
      "transaction_type": "AUTH_CAPTURE",
      "transaction_token": "4Tczi4OI12MeoSaC4FG2VPKj1",
      "transaction_id": "257494-0_10",
      "payment_transaction_id": 10,
      "original_transaction_id": 110,
      "apply_to": "JOB",
      "amount": 10.35,
      "memo": null,
      "authorization_code": "755972",
      "bill_to_street_address": "adddad",
      "bill_to_postal_code": "adadadd",
      "bill_to_country": null,
      "reference_number": "1976/1410",
      "is_resync_qbo": false,
      "created_at": "2015-09-25T09:56:57+00:00",
      "updated_at": "2015-09-25T09:56:57+00:00",
      "received_on": "2015-09-25T00:00:00+00:00",
      "qbo_synced_date": "2015-09-25T00:00:00+00:00",
      "qbo_id": 5,
      "qbd_id": "3792-1438659918",
      "customer": "Max Paltsev",
      "type": "Cash",
      "invoice_id": 124,
      "gateway_id": 980190963,
      "receipt_id": "ord-250915-9:56:56"
    }
  ],
  "signatures": [
    {
      "type": "PREWORK",
      "file_name": "https://servicefusion.s3.amazonaws.com/images/sign/139350-2015-08-25-11-35-14.png",
      "created_at": "2015-08-25T11:35:14+00:00",
      "updated_at": "2015-08-25T11:35:14+00:00"
    }
  ],
  "printable_work_order": [
    {
      "name": "Print With Rates",
      "url": "https://servicefusion.com/printJobWithRates?jobId=fF7HY2Dew1E9vw2mm8FHzSOrpDrKnSl-m2WKf0Yg_Kw"
    }
  ],
  "tags": [
    {
      "tag": "Referral",
      "created_at": "2017-03-20T10:48:38+00:00",
      "updated_at": "2017-03-20T10:48:38+00:00"
    }
  ]
}
```

### EstimateBody

An estimate's body schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `description` | `string` | optional | Used to send the estimate's description that will be set. |
| `tech_notes` | `string` | optional | Used to send the estimate's tech notes that will be set. |
| `duration` | `integer` | optional | Used to send the estimate's duration (in seconds) that will be set. (default: `3600`) |
| `time_frame_promised_start` | `string` | optional | Used to send the estimate's time frame promised start that will be set. |
| `time_frame_promised_end` | `string` | optional | Used to send the estimate's time frame promised end that will be set. |
| `start_date` | `datetime` | optional | Used to send the estimate's start date that will be set. |
| `created_at` | `datetime` | optional | Used to send the estimate's created date that will be set. (default: `If not passed, it takes the value as current date and time.`) |
| `customer_name` | `string` | **required** | Used to send a customer's `id` or `header` that will be attached to the estimate (Note: `id` - [integer] the customer's identifier, `header` - [string] the customer's fields concatenated by pattern `{customer_name}`). |
| `status` | `string` | optional | Used to send a status'es `id` or `header` that will be attached to the estimate (Note: `id` - [integer] the status'es identifier, `header` - [string] the status'es fields concatenated by pattern `{name}`). (default: `If not passed, it takes the default status for estimates.`) |
| `contact_first_name` | `string` | optional | Used to send the estimate's contact first name that will be set. If a contact with the passed name and surname already exists, then a new contact will not be created, but the existing one will be attached. (default: `If not passed, it takes the first name from primary contact of the customer (if exists), otherwise a primary contact will be created for the customer.`) |
| `contact_last_name` | `string` | optional | Used to send the estimate's contact last name that will be set. If a contact with the passed name and surname already exists, then a new contact will not be created, but the existing one will be attached. (default: `If not passed, it takes the last name from primary contact of the customer (if exists), otherwise a primary contact will be created for the customer.`) |
| `street_1` | `string` | optional | Used to send the estimate's location street 1 that will be set. (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) |
| `street_2` | `string` | optional | Used to send the estimate's location street 2 that will be set. (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) |
| `city` | `string` | optional | Used to send the estimate's location city that will be set. (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) |
| `state_prov` | `string` | optional | Used to send the estimate's location state prov that will be set. (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) |
| `postal_code` | `string` | optional | Used to send the estimate's location postal code that will be set. (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) |
| `location_name` | `string` | optional | Used to send the estimate's location name that will be set. (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) |
| `is_gated` | `boolean` | optional | Used to send the estimate's location is gated flag that will be set. (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) |
| `gate_instructions` | `string` | optional | Used to send the estimate's location gate instructions that will be set. (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) |
| `category` | `string` | optional | Used to send a category's `id` or `header` that will be attached to the estimate (Note: `id` - [integer] the category's identifier, `header` - [string] the category's fields concatenated by pattern `{category}`). Optionally required (configurable into the company preferences). |
| `source` | `string` | optional | Used to send a source's `id` or `header` that will be attached to the estimate (Note: `id` - [integer] the source's identifier, `header` - [string] the source's fields concatenated by pattern `{short_name}`). (default: `If not passed, it takes the value from the customer.`) |
| `project` | `string` | optional | Used to send a project's `id` or `header` that will be attached to the estimate (Note: `id` - [integer] the project's identifier, `header` - [string] the project's fields concatenated by pattern `{name}`). |
| `phase` | `string` | optional | Used to send a phase's `id` or `header` that will be attached to the estimate (Note: `id` - [integer] the phase's identifier, `header` - [string] the phase's fields concatenated by pattern `{name}`). |
| `po_number` | `string` | optional | Used to send the estimate's po number that will be set. |
| `contract` | `string` | optional | Used to send a contract's `id` or `header` that will be attached to the estimate (Note: `id` - [integer] the contract's identifier, `header` - [string] the contract's fields concatenated by pattern `{contract_title}`). (default: `If not passed, it takes the value from the customer.`) |
| `note_to_customer` | `string` | optional | Used to send the estimate's note to customer that will be set. (default: `If not passed, it takes the value from the company preferences.`) |
| `opportunity_rating` | `integer` | optional | Used to send the estimate's opportunity rating that will be set. |
| `opportunity_owner` | `string` | optional | Used to send an opportunity owner's `id` or `header` that will be attached to the estimate (Note: `id` - [integer] the opportunity owner's identifier, `header` - [string] the opportunity owner's fields concatenated by pattern `{first_name} {last_name}` with space as separator). (default: `If not passed, it takes the value from the authenticated user.`) |
| `custom_fields` | `array` | optional | Used to send the estimate's custom fields list that will be set. (default: `If some custom field (configured into the custom fields settings) not passed, it creates the new one with its default value.`) |
| `equipment` | `array` | optional | Used to send the estimate's equipments list that will be set. (default: `array`) |
| `techs_assigned` | `array` | optional | Used to send the estimate's techs assigned list that will be set. (default: `array`) |
| `tasks` | `array` | optional | Used to send the estimate's tasks list that will be set. (default: `array`) |
| `notes` | `array` | optional | Used to send the estimate's notes list that will be set. (default: `array`) |
| `products` | `array` | optional | Used to send the estimate's products list that will be set. (default: `array`) |
| `services` | `array` | optional | Used to send the estimate's services list that will be set. (default: `array`) |
| `other_charges` | `array` | optional | Used to send the estimate's other charges list that will be set. (default: `If not passed, it creates all entries with `auto added` option enabled. Also it creates all not passed other charges declared into `products` and `services`.`) |
| `tags` | `array` | optional | Used to send the estimate's tags list that will be set. (default: `array`) |

**Example:**
```json
{
  "description": "This is a test",
  "tech_notes": "You guys know what to do.",
  "duration": 3600,
  "time_frame_promised_start": "14:10",
  "time_frame_promised_end": "15:10",
  "start_date": "2015-01-08",
  "created_at": "2014-09-08T20:42:04+00:00",
  "customer_name": "Max Paltsev",
  "status": "Cancelled",
  "contact_first_name": "Sam",
  "contact_last_name": "Smith",
  "street_1": "1904 Industrial Blvd",
  "street_2": "103",
  "city": "Colleyville",
  "state_prov": "Texas",
  "postal_code": "76034",
  "location_name": "Office",
  "is_gated": true,
  "gate_instructions": "Gate instructions for customer",
  "category": "Quick Home Energy Check-ups",
  "source": "Yellow Pages",
  "project": "reshma",
  "phase": "Closeup",
  "po_number": "86305",
  "contract": "Retail Service Contract",
  "note_to_customer": "Sample Note To Customer.",
  "opportunity_rating": 4,
  "opportunity_owner": "John Theowner",
  "custom_fields": [
    {
      "name": "Text",
      "value": "Example text value"
    },
    {
      "name": "Textarea",
      "value": "Example text area value"
    },
    {
      "name": "Date",
      "value": "2018-10-05"
    },
    {
      "name": "Numeric",
      "value": "157.25"
    },
    {
      "name": "Select",
      "value": "1 one"
    },
    {
      "name": "Checkbox",
      "value": true
    }
  ],
  "equipment": [
    {
      "id": "COIL:ABUS:LMU-2620i:445577998871",
      "type": "Test Equipment",
      "make": "New Test Manufacturer",
      "model": "TST1231MOD",
      "sku": "SK15432",
      "serial_number": "1231#SRN",
      "location": "Test Location",
      "notes": "Test notes for the Test Equipment",
      "extended_warranty_provider": "Test War Provider",
      "is_extended_warranty": false,
      "extended_warranty_date": "2015-02-17",
      "warranty_date": "2015-01-16",
      "install_date": "2014-12-15",
      "customer_location": "Office",
      "custom_fields": [
        {
          "name": "Text",
          "value": "Example text value"
        },
        {
          "name": "Textarea",
          "value": "Example text area value"
        },
        {
          "name": "Date",
          "value": "2018-10-05"
        },
        {
          "name": "Numeric",
          "value": "157.25"
        },
        {
          "name": "Select",
          "value": "1 one"
        },
        {
          "name": "Checkbox",
          "value": true
        }
      ]
    }
  ],
  "techs_assigned": [
    {
      "id": 31
    },
    {
      "first_name": "John",
      "last_name": "Theowner"
    }
  ],
  "tasks": [
    {
      "description": "x",
      "is_completed": false
    }
  ],
  "notes": [
    {
      "notes": "SHOULD BE DELIVERED TO US 6/1/15 AND RICHARD NEEDS TO PAINT"
    }
  ],
  "products": [
    {
      "name": "1755LFB-NEW",
      "description": "Finishing Trim Kit - 1\" - Black\r\nModel: \r\nSKU: \r\nType: \r\nPart Number: ",
      "multiplier": 2,
      "rate": 500,
      "cost": 100,
      "is_show_rate_items": false,
      "tax": "FIXED",
      "product": "1755LFB"
    }
  ],
  "services": [
    {
      "name": "Service Call Fee",
      "description": null,
      "multiplier": 1,
      "rate": "33.15",
      "cost": "121",
      "is_show_rate_items": true,
      "tax": "City Tax",
      "service": "Nabeeel"
    }
  ],
  "other_charges": [
    {
      "name": "fee1 new",
      "rate": "15.15",
      "is_percentage": false,
      "other_charge": "fee1"
    }
  ],
  "tags": [
    {
      "tag": "Referral"
    }
  ]
}
```

### EstimateView

An estimate's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | The estimate's identifier. |
| `number` | `string` | optional | The estimate's number. |
| `description` | `string` | optional | The estimate's description. |
| `tech_notes` | `string` | optional | The estimate's tech notes. |
| `customer_payment_terms` | `string` | optional | The estimate's customer payment terms. |
| `payment_status` | `string` | optional | The estimate's payment status. |
| `taxes_fees_total` | `number` | optional | The estimate's taxes and fees total. |
| `total` | `number` | optional | The estimate's total. |
| `due_total` | `number` | optional | The estimate's due total. |
| `cost_total` | `number` | optional | The estimate's cost total. |
| `duration` | `integer` | optional | The estimate's duration (in seconds). |
| `time_frame_promised_start` | `string` | optional | The estimate's time frame promised start. |
| `time_frame_promised_end` | `string` | optional | The estimate's time frame promised end. |
| `start_date` | `datetime` | optional | The estimate's start date. |
| `created_at` | `datetime` | optional | The estimate's created date. |
| `updated_at` | `datetime` | optional | The estimate's updated date. |
| `customer_id` | `integer` | optional | The `id` of attached customer to the estimate (Note: `id` - [integer] the customer's identifier). |
| `customer_name` | `string` | optional | The `header` of attached customer to the estimate (Note: `header` - [string] the customer's fields concatenated by pattern `{customer_name}`). |
| `parent_customer` | `string` | optional | The `header` of attached parent customer to the estimate (Note: `header` - [string] the parent customer's fields concatenated by pattern `{customer_name}`). |
| `status` | `string` | optional | The `header` of attached status to the estimate (Note: `header` - [string] the status'es fields concatenated by pattern `{name}`). |
| `sub_status` | `string` | optional | The `header` of attached sub status to the estimate (Note: `header` - [string] the sub status's fields concatenated by pattern `{name}`). |
| `contact_first_name` | `string` | optional | The estimate's contact first name. |
| `contact_last_name` | `string` | optional | The estimate's contact last name. |
| `street_1` | `string` | optional | The estimate's location street 1. |
| `street_2` | `string` | optional | The estimate's location street 2. |
| `city` | `string` | optional | The estimate's location city. |
| `state_prov` | `string` | optional | The estimate's location state prov. |
| `postal_code` | `string` | optional | The estimate's location postal code. |
| `location_name` | `string` | optional | The estimate's location name. |
| `is_gated` | `boolean` | optional | The estimate's location is gated flag. |
| `gate_instructions` | `string` | optional | The estimate's location gate instructions. |
| `category` | `string` | optional | The `header` of attached category to the estimate (Note: `header` - [string] the category's fields concatenated by pattern `{category}`). |
| `source` | `string` | optional | The `header` of attached source to the estimate (Note: `header` - [string] the source's fields concatenated by pattern `{short_name}`). |
| `payment_type` | `string` | optional | The `header` of attached payment type to the estimate (Note: `header` - [string] the payment type's fields concatenated by pattern `{short_name}`). |
| `project` | `string` | optional | The `header` of attached project to the estimate (Note: `header` - [string] the project's fields concatenated by pattern `{name}`). |
| `phase` | `string` | optional | The `header` of attached phase to the estimate (Note: `header` - [string] the phase's fields concatenated by pattern `{name}`). |
| `po_number` | `string` | optional | The estimate's po number. |
| `contract` | `string` | optional | The `header` of attached contract to the estimate (Note: `header` - [string] the contract's fields concatenated by pattern `{contract_title}`). |
| `note_to_customer` | `string` | optional | The estimate's note to customer. |
| `opportunity_rating` | `integer` | optional | The estimate's opportunity rating. |
| `opportunity_owner` | `string` | optional | The `header` of attached opportunity owner to the estimate (Note: `header` - [string] the opportunity owner's fields concatenated by pattern `{first_name} {last_name}` with space as separator). |
| `agents` | `array` | optional | The estimate's agents list. |
| `custom_fields` | `array` | optional | The estimate's custom fields list. |
| `pictures` | `array` | optional | The estimate's pictures list. |
| `documents` | `array` | optional | The estimate's documents list. |
| `equipment` | `array` | optional | The estimate's equipments list. |
| `techs_assigned` | `array` | optional | The estimate's techs assigned list. |
| `tasks` | `array` | optional | The estimate's tasks list. |
| `notes` | `array` | optional | The estimate's notes list. |
| `products` | `array` | optional | The estimate's products list. |
| `services` | `array` | optional | The estimate's services list. |
| `other_charges` | `array` | optional | The estimate's other charges list. |
| `payments` | `array` | optional | The estimate's payments list. |
| `signatures` | `array` | optional | The estimate's signatures list. |
| `printable_work_order` | `array` | optional | The estimate's printable work order list. |
| `tags` | `array` | optional | The estimate's tags list. |
| `_expandable` | `array` | **required** | The extra-field's list that are not expanded and can be expanded into objects. |

**Example:**
```json
{
  "id": 13,
  "number": "1152157",
  "description": "This is a test",
  "tech_notes": "You guys know what to do.",
  "customer_payment_terms": "COD",
  "payment_status": "Unpaid",
  "taxes_fees_total": 193.25,
  "total": 193,
  "due_total": 193,
  "cost_total": 0,
  "duration": 3600,
  "time_frame_promised_start": "14:10",
  "time_frame_promised_end": "14:10",
  "start_date": "2015-01-08",
  "created_at": "2014-09-08T20:42:04+00:00",
  "updated_at": "2016-01-07T17:20:36+00:00",
  "customer_id": 11,
  "customer_name": "Max Paltsev",
  "parent_customer": "Jerry Wheeler",
  "status": "Cancelled",
  "sub_status": "job1",
  "contact_first_name": "Sam",
  "contact_last_name": "Smith",
  "street_1": "1904 Industrial Blvd",
  "street_2": "103",
  "city": "Colleyville",
  "state_prov": "Texas",
  "postal_code": "76034",
  "location_name": "Office",
  "is_gated": false,
  "gate_instructions": null,
  "category": "Quick Home Energy Check-ups",
  "source": "Yellow Pages",
  "payment_type": "Direct Bill",
  "project": "reshma",
  "phase": "Closeup",
  "po_number": "86305",
  "contract": "Retail Service Contract",
  "note_to_customer": "Sample Note To Customer.",
  "opportunity_rating": 4,
  "opportunity_owner": "John Theowner",
  "agents": [
    {
      "id": 31,
      "first_name": "Justin",
      "last_name": "Wormell"
    },
    {
      "id": 32,
      "first_name": "John",
      "last_name": "Theowner"
    }
  ],
  "custom_fields": [
    {
      "name": "Text",
      "value": "Example text value",
      "type": "text",
      "group": "Default",
      "created_at": "2018-10-11T11:52:33+00:00",
      "updated_at": "2018-10-11T11:52:33+00:00",
      "is_required": true
    }
  ],
  "pictures": [
    {
      "name": "1442951633_images.jpeg",
      "file_location": "1442951633_images.jpeg",
      "doc_type": "IMG",
      "comment": null,
      "sort": 2,
      "is_private": false,
      "created_at": "2015-09-22T19:53:53+00:00",
      "updated_at": "2015-09-22T19:53:53+00:00",
      "customer_doc_id": 992
    }
  ],
  "documents": [
    {
      "name": "test1John.pdf",
      "file_location": "1421408539_test1John.pdf",
      "doc_type": "DOC",
      "comment": null,
      "sort": 1,
      "is_private": false,
      "created_at": "2015-01-16T11:42:19+00:00",
      "updated_at": "2018-08-21T08:21:14+00:00",
      "customer_doc_id": 998
    }
  ],
  "equipment": [
    {
      "id": 12,
      "type": "Test Equipment",
      "make": "New Test Manufacturer",
      "model": "TST1231MOD",
      "sku": "SK15432",
      "serial_number": "1231#SRN",
      "location": "Test Location",
      "notes": "Test notes for the Test Equipment",
      "extended_warranty_provider": "Test War Provider",
      "is_extended_warranty": false,
      "extended_warranty_date": "2015-02-17",
      "warranty_date": "2015-01-16",
      "install_date": "2014-12-15",
      "created_at": "2015-01-16T11:31:49+00:00",
      "updated_at": "2015-01-16T11:31:49+00:00",
      "customer_id": 87,
      "customer": "John Theowner",
      "customer_location": "Office",
      "custom_fields": [
        {
          "name": "Text",
          "value": "Example text value",
          "type": "text",
          "group": "Default",
          "created_at": "2018-10-11T11:52:33+00:00",
          "updated_at": "2018-10-11T11:52:33+00:00",
          "is_required": true
        }
      ]
    }
  ],
  "techs_assigned": [
    {
      "id": 31,
      "first_name": "Justin",
      "last_name": "Wormell"
    },
    {
      "id": 32,
      "first_name": "John",
      "last_name": "Theowner"
    }
  ],
  "tasks": [
    {
      "type": "Misc",
      "description": "x",
      "start_time": null,
      "start_date": null,
      "end_date": null,
      "is_completed": false,
      "created_at": "2017-03-20T10:48:38+00:00",
      "updated_at": "2017-03-20T10:48:38+00:00"
    }
  ],
  "notes": [
    {
      "notes": "SHOULD BE DELIVERED TO US 6/1/15 AND RICHARD NEEDS TO PAINT",
      "created_at": "2015-05-27T16:32:06+00:00",
      "updated_at": "2015-05-27T16:32:06+00:00"
    }
  ],
  "products": [
    {
      "name": "1755LFB",
      "description": "Finishing Trim Kit - 1\" - Black\r\nModel: \r\nSKU: \r\nType: \r\nPart Number: ",
      "multiplier": 3,
      "rate": 459,
      "total": 1377,
      "cost": 0,
      "actual_cost": 0,
      "item_index": 0,
      "parent_index": 0,
      "created_at": "2015-08-20T09:08:36+00:00",
      "updated_at": "2015-11-19T20:38:07+00:00",
      "is_show_rate_items": true,
      "tax": "City Tax",
      "product": "1755LFB",
      "product_list_id": 45302,
      "warehouse_id": 200,
      "pattern_row_id": null,
      "qbo_class_id": null,
      "qbd_class_id": null
    }
  ],
  "services": [
    {
      "name": "Service Call Fee",
      "description": null,
      "multiplier": 1,
      "rate": 33.15,
      "total": 121,
      "cost": 121,
      "actual_cost": 121,
      "item_index": 3,
      "parent_index": 0,
      "created_at": "2015-08-20T09:08:36+00:00",
      "updated_at": "2015-11-19T20:38:07+00:00",
      "is_show_rate_items": true,
      "tax": "City Tax",
      "service": "Nabeeel",
      "service_list_id": 45302,
      "service_rate_id": 200,
      "pattern_row_id": null,
      "qbo_class_id": null,
      "qbd_class_id": null
    }
  ],
  "other_charges": [
    {
      "name": "fee1",
      "rate": 5.15,
      "total": 14.3,
      "charge_index": 1,
      "parent_index": 1,
      "is_percentage": true,
      "is_discount": false,
      "created_at": "2015-08-20T09:08:52+00:00",
      "updated_at": "2015-11-19T20:38:07+00:00",
      "other_charge": "fee1",
      "applies_to": null,
      "service_list_id": null,
      "other_charge_id": 248,
      "pattern_row_id": null,
      "qbo_class_id": null,
      "qbd_class_id": null
    }
  ],
  "payments": [
    {
      "transaction_type": "AUTH_CAPTURE",
      "transaction_token": "4Tczi4OI12MeoSaC4FG2VPKj1",
      "transaction_id": "257494-0_10",
      "payment_transaction_id": 10,
      "original_transaction_id": 110,
      "apply_to": "JOB",
      "amount": 10.35,
      "memo": null,
      "authorization_code": "755972",
      "bill_to_street_address": "adddad",
      "bill_to_postal_code": "adadadd",
      "bill_to_country": null,
      "reference_number": "1976/1410",
      "is_resync_qbo": false,
      "created_at": "2015-09-25T09:56:57+00:00",
      "updated_at": "2015-09-25T09:56:57+00:00",
      "received_on": "2015-09-25T00:00:00+00:00",
      "qbo_synced_date": "2015-09-25T00:00:00+00:00",
      "qbo_id": 5,
      "qbd_id": "3792-1438659918",
      "customer": "Max Paltsev",
      "type": "Cash",
      "invoice_id": 124,
      "gateway_id": 980190963,
      "receipt_id": "ord-250915-9:56:56"
    }
  ],
  "signatures": [
    {
      "type": "PREWORK",
      "file_name": "https://servicefusion.s3.amazonaws.com/images/sign/139350-2015-08-25-11-35-14.png",
      "created_at": "2015-08-25T11:35:14+00:00",
      "updated_at": "2015-08-25T11:35:14+00:00"
    }
  ],
  "printable_work_order": [
    {
      "name": "Print With Rates",
      "url": "https://servicefusion.com/printJobWithRates?jobId=fF7HY2Dew1E9vw2mm8FHzSOrpDrKnSl-m2WKf0Yg_Kw"
    }
  ],
  "tags": [
    {
      "tag": "Referral",
      "created_at": "2017-03-20T10:48:38+00:00",
      "updated_at": "2017-03-20T10:48:38+00:00"
    }
  ],
  "_expandable": [
    "agents",
    "custom_fields",
    "pictures",
    "documents",
    "equipment",
    "equipment.custom_fields",
    "techs_assigned",
    "tasks",
    "notes",
    "products",
    "services",
    "other_charges",
    "payments",
    "signatures",
    "printable_work_order",
    "tags"
  ]
}
```

### Invoice

An invoice's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | The invoice's identifier. |
| `number` | `integer` | optional | The invoice's number. |
| `currency` | `string` | optional | The invoice's currency. |
| `po_number` | `string` | optional | The invoice's po number. |
| `terms` | `string` | optional | The invoice's terms. |
| `customer_message` | `string` | optional | The invoice's customer message. |
| `notes` | `string` | optional | The invoice's notes. |
| `pay_online_url` | `string` | optional | The invoice's pay online url. |
| `qbo_invoice_no` | `integer` | optional | The invoice's qbo invoice no. |
| `qbo_sync_token` | `integer` | optional | The invoice's qbo sync token. |
| `qbo_synced_date` | `datetime` | optional | The invoice's qbo synced date. |
| `qbo_id` | `integer` | optional | The invoice's qbo class id. |
| `qbd_id` | `string` | optional | The invoice's qbd class id. |
| `total` | `number` | optional | The invoice's total. |
| `is_paid` | `boolean` | optional | The invoice's is paid flag. |
| `date` | `datetime` | optional | The invoice's date. |
| `mail_send_date` | `datetime` | optional | The invoice's mail send date. |
| `created_at` | `datetime` | optional | The invoice's created date. |
| `updated_at` | `datetime` | optional | The invoice's updated date. |
| `customer` | `string` | optional | The `header` of attached customer to the invoice (Note: `header` - [string] the customer's fields concatenated by pattern `{customer_name}`). |
| `customer_contact` | `string` | optional | The `header` of attached customer contact to the invoice (Note: `header` - [string] the customer contact's fields concatenated by pattern `{fname} {lname}` with space as separator). |
| `payment_terms` | `string` | optional | The `header` of attached payment term to the invoice (Note: `header` - [string] the payment term's fields concatenated by pattern `{name}`). |
| `bill_to_customer_id` | `integer` | optional | The `id` of attached bill to customer to the invoice (Note: `id` - [integer] the bill to customer's identifier). |
| `bill_to_customer_location_id` | `integer` | optional | The `id` of attached bill to customer location to the invoice (Note: `id` - [integer] the bill to customer location's identifier). |
| `bill_to_customer_contact_id` | `integer` | optional | The `id` of attached bill to customer contact to the invoice (Note: `id` - [integer] the bill to customer contact's identifier). |
| `bill_to_email_id` | `integer` | optional | The `id` of attached bill to email to the invoice (Note: `id` - [integer] the bill to email's identifier). |
| `bill_to_phone_id` | `integer` | optional | The `id` of attached bill to phone to the invoice (Note: `id` - [integer] the bill to phone's identifier). |

**Example:**
```json
{
  "id": 13,
  "number": 1001,
  "currency": "$",
  "po_number": null,
  "terms": "DUR",
  "customer_message": null,
  "notes": null,
  "pay_online_url": "https://app.servicefusion.com/invoiceOnline?id=WP7y6F6Ff48NqjQym4qX1maGXL_1oljugHAP0fNVaBg&key=0DtZ_Q5p4UZNqQHcx08U1k2dx8B3ZHKg3pBxavOtH61",
  "qbo_invoice_no": null,
  "qbo_sync_token": null,
  "qbo_synced_date": "2014-01-21T22:11:31+00:00",
  "qbo_id": null,
  "qbd_id": null,
  "total": 268.32,
  "is_paid": false,
  "date": "2014-01-21T00:00:00+00:00",
  "mail_send_date": null,
  "created_at": "2014-01-21T22:11:31+00:00",
  "updated_at": "2014-01-21T22:11:31+00:00",
  "customer": null,
  "customer_contact": null,
  "payment_terms": "Due Upon Receipt",
  "bill_to_customer_id": null,
  "bill_to_customer_location_id": null,
  "bill_to_customer_contact_id": null,
  "bill_to_email_id": null,
  "bill_to_phone_id": null
}
```

### InvoiceView

An invoice's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | The invoice's identifier. |
| `number` | `integer` | optional | The invoice's number. |
| `currency` | `string` | optional | The invoice's currency. |
| `po_number` | `string` | optional | The invoice's po number. |
| `terms` | `string` | optional | The invoice's terms. |
| `customer_message` | `string` | optional | The invoice's customer message. |
| `notes` | `string` | optional | The invoice's notes. |
| `pay_online_url` | `string` | optional | The invoice's pay online url. |
| `qbo_invoice_no` | `integer` | optional | The invoice's qbo invoice no. |
| `qbo_sync_token` | `integer` | optional | The invoice's qbo sync token. |
| `qbo_synced_date` | `datetime` | optional | The invoice's qbo synced date. |
| `qbo_id` | `integer` | optional | The invoice's qbo class id. |
| `qbd_id` | `string` | optional | The invoice's qbd class id. |
| `total` | `number` | optional | The invoice's total. |
| `is_paid` | `boolean` | optional | The invoice's is paid flag. |
| `date` | `datetime` | optional | The invoice's date. |
| `mail_send_date` | `datetime` | optional | The invoice's mail send date. |
| `created_at` | `datetime` | optional | The invoice's created date. |
| `updated_at` | `datetime` | optional | The invoice's updated date. |
| `customer` | `string` | optional | The `header` of attached customer to the invoice (Note: `header` - [string] the customer's fields concatenated by pattern `{customer_name}`). |
| `customer_contact` | `string` | optional | The `header` of attached customer contact to the invoice (Note: `header` - [string] the customer contact's fields concatenated by pattern `{fname} {lname}` with space as separator). |
| `payment_terms` | `string` | optional | The `header` of attached payment term to the invoice (Note: `header` - [string] the payment term's fields concatenated by pattern `{name}`). |
| `bill_to_customer_id` | `integer` | optional | The `id` of attached bill to customer to the invoice (Note: `id` - [integer] the bill to customer's identifier). |
| `bill_to_customer_location_id` | `integer` | optional | The `id` of attached bill to customer location to the invoice (Note: `id` - [integer] the bill to customer location's identifier). |
| `bill_to_customer_contact_id` | `integer` | optional | The `id` of attached bill to customer contact to the invoice (Note: `id` - [integer] the bill to customer contact's identifier). |
| `bill_to_email_id` | `integer` | optional | The `id` of attached bill to email to the invoice (Note: `id` - [integer] the bill to email's identifier). |
| `bill_to_phone_id` | `integer` | optional | The `id` of attached bill to phone to the invoice (Note: `id` - [integer] the bill to phone's identifier). |
| `_expandable` | `array` | **required** | The extra-field's list that are not expanded and can be expanded into objects. |

**Example:**
```json
{
  "id": 13,
  "number": 1001,
  "currency": "$",
  "po_number": null,
  "terms": "DUR",
  "customer_message": null,
  "notes": null,
  "pay_online_url": "https://app.servicefusion.com/invoiceOnline?id=WP7y6F6Ff48NqjQym4qX1maGXL_1oljugHAP0fNVaBg&key=0DtZ_Q5p4UZNqQHcx08U1k2dx8B3ZHKg3pBxavOtH61",
  "qbo_invoice_no": null,
  "qbo_sync_token": null,
  "qbo_synced_date": "2014-01-21T22:11:31+00:00",
  "qbo_id": null,
  "qbd_id": null,
  "total": 268.32,
  "is_paid": false,
  "date": "2014-01-21T00:00:00+00:00",
  "mail_send_date": null,
  "created_at": "2014-01-21T22:11:31+00:00",
  "updated_at": "2014-01-21T22:11:31+00:00",
  "customer": null,
  "customer_contact": null,
  "payment_terms": "Due Upon Receipt",
  "bill_to_customer_id": null,
  "bill_to_customer_location_id": null,
  "bill_to_customer_contact_id": null,
  "bill_to_email_id": null,
  "bill_to_phone_id": null,
  "_expandable": []
}
```

### Job

A job's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | The job's identifier. |
| `number` | `string` | optional | The job's number. |
| `check_number` | `string` | optional | The job's check number. |
| `priority` | `string` | optional | The job's priority. |
| `description` | `string` | optional | The job's description. |
| `tech_notes` | `string` | optional | The job's tech notes. |
| `completion_notes` | `string` | optional | The job's completion notes. |
| `payment_status` | `string` | optional | The job's payment status. |
| `taxes_fees_total` | `number` | optional | The job's taxes and fees total. |
| `drive_labor_total` | `number` | optional | The job's drive and labor total. |
| `billable_expenses_total` | `number` | optional | The job's billable expenses total. |
| `total` | `number` | optional | The job's total. |
| `payments_deposits_total` | `number` | optional | The job's payments and deposits total. |
| `due_total` | `number` | optional | The job's due total. |
| `cost_total` | `number` | optional | The job's cost total. |
| `duration` | `integer` | optional | The job's duration (in seconds). |
| `time_frame_promised_start` | `string` | optional | The job's time frame promised start. |
| `time_frame_promised_end` | `string` | optional | The job's time frame promised end. |
| `start_date` | `datetime` | optional | The job's start date. |
| `end_date` | `datetime` | optional | The job's end date. |
| `created_at` | `datetime` | optional | The job's created date. |
| `updated_at` | `datetime` | optional | The job's updated date. |
| `closed_at` | `datetime` | optional | The job's closed date. |
| `customer_id` | `integer` | optional | The `id` of attached customer to the job (Note: `id` - [integer] the customer's identifier). |
| `customer_name` | `string` | optional | The `header` of attached customer to the job (Note: `header` - [string] the customer's fields concatenated by pattern `{customer_name}`). |
| `parent_customer` | `string` | optional | The `header` of attached parent customer to the job (Note: `header` - [string] the parent customer's fields concatenated by pattern `{customer_name}`). |
| `status` | `string` | optional | The `header` of attached status to the job (Note: `header` - [string] the status'es fields concatenated by pattern `{name}`). |
| `sub_status` | `string` | optional | The `header` of attached sub status to the job (Note: `header` - [string] the sub status's fields concatenated by pattern `{name}`). |
| `contact_first_name` | `string` | optional | The job's contact first name. |
| `contact_last_name` | `string` | optional | The job's contact last name. |
| `street_1` | `string` | optional | The job's location street 1. |
| `street_2` | `string` | optional | The job's location street 2. |
| `city` | `string` | optional | The job's location city. |
| `state_prov` | `string` | optional | The job's location state prov. |
| `postal_code` | `string` | optional | The job's location postal code. |
| `location_name` | `string` | optional | The job's location name. |
| `is_gated` | `boolean` | optional | The job's location is gated flag. |
| `gate_instructions` | `string` | optional | The job's location gate instructions. |
| `category` | `string` | optional | The `header` of attached category to the job (Note: `header` - [string] the category's fields concatenated by pattern `{category}`). |
| `source` | `string` | optional | The `header` of attached source to the job (Note: `header` - [string] the source's fields concatenated by pattern `{short_name}`). |
| `payment_type` | `string` | optional | The `header` of attached payment type to the job (Note: `header` - [string] the payment type's fields concatenated by pattern `{short_name}`). |
| `customer_payment_terms` | `string` | optional | The `header` of attached customer payment term to the job (Note: `header` - [string] the customer payment term's fields concatenated by pattern `{name}`). |
| `project` | `string` | optional | The `header` of attached project to the job (Note: `header` - [string] the project's fields concatenated by pattern `{name}`). |
| `phase` | `string` | optional | The `header` of attached phase to the job (Note: `header` - [string] the phase's fields concatenated by pattern `{name}`). |
| `po_number` | `string` | optional | The job's po number. |
| `contract` | `string` | optional | The `header` of attached contract to the job (Note: `header` - [string] the contract's fields concatenated by pattern `{contract_title}`). |
| `note_to_customer` | `string` | optional | The job's note to customer. |
| `called_in_by` | `string` | optional | The job's called in by. |
| `is_requires_follow_up` | `boolean` | optional | The job's is requires follow up flag. |
| `agents` | `array` | optional | The job's agents list. |
| `custom_fields` | `array` | optional | The job's custom fields list. |
| `pictures` | `array` | optional | The job's pictures list. |
| `documents` | `array` | optional | The job's documents list. |
| `equipment` | `array` | optional | The job's equipments list. |
| `techs_assigned` | `array` | optional | The job's techs assigned list. |
| `tasks` | `array` | optional | The job's tasks list. |
| `notes` | `array` | optional | The job's notes list. |
| `products` | `array` | optional | The job's products list. |
| `services` | `array` | optional | The job's services list. |
| `other_charges` | `array` | optional | The job's other charges list. |
| `labor_charges` | `array` | optional | The job's labor charges list. |
| `expenses` | `array` | optional | The job's expenses list. |
| `payments` | `array` | optional | The job's payments list. |
| `invoices` | `array` | optional | The job's invoices list. |
| `signatures` | `array` | optional | The job's signatures list. |
| `printable_work_order` | `array` | optional | The job's printable work order list. |
| `visits` | `array` | optional | The job's visits list. |

### JobBody

A job's body schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `check_number` | `string` | optional | Used to send the job's check number that will be set. |
| `priority` | `string` | optional | Used to send the job's priority that will be set. (default: `Normal`) Enum: `Low`, `Normal`, `High` |
| `description` | `string` | optional | Used to send the job's description that will be set. |
| `tech_notes` | `string` | optional | Used to send the job's tech notes that will be set. |
| `completion_notes` | `string` | optional | Used to send the job's completion notes that will be set. |
| `duration` | `integer` | optional | Used to send the job's duration (in seconds) that will be set. (default: `3600`) |
| `time_frame_promised_start` | `string` | optional | Used to send the job's time frame promised start that will be set. |
| `time_frame_promised_end` | `string` | optional | Used to send the job's time frame promised end that will be set. |
| `start_date` | `datetime` | optional | Used to send the job's start date that will be set. |
| `end_date` | `datetime` | optional | Used to send the job's end date that will be set. |
| `customer_name` | `string` | **required** | Used to send a customer's `id` or `header` that will be attached to the job (Note: `id` - [integer] the customer's identifier, `header` - [string] the customer's fields concatenated by pattern `{customer_name}`). |
| `status` | `string` | optional | Used to send a status'es `id` or `header` that will be attached to the job (Note: `id` - [integer] the status'es identifier, `header` - [string] the status'es fields concatenated by pattern `{name}`). Optionally required (configurable into the company preferences). (default: `If not passed, it takes the default status for jobs.`) |
| `contact_first_name` | `string` | optional | Used to send the job's contact first name that will be set. If a contact with the passed name and surname already exists, then a new contact will not be created, but the existing one will be attached. (default: `If not passed, it takes the first name from primary contact of the customer (if exists), otherwise a primary contact will be created for the customer.`) |
| `contact_last_name` | `string` | optional | Used to send the job's contact last name that will be set. If a contact with the passed name and surname already exists, then a new contact will not be created, but the existing one will be attached. (default: `If not passed, it takes the last name from primary contact of the customer (if exists), otherwise a primary contact will be created for the customer.`) |
| `street_1` | `string` | optional | Used to send the job's location street 1 that will be set. (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) |
| `street_2` | `string` | optional | Used to send the job's location street 2 that will be set. (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) |
| `city` | `string` | optional | Used to send the job's location city that will be set. (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) |
| `state_prov` | `string` | optional | Used to send the job's location state prov that will be set. (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) |
| `postal_code` | `string` | optional | Used to send the job's location postal code that will be set. (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) |
| `location_name` | `string` | optional | Used to send the job's location name that will be set. (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) |
| `is_gated` | `boolean` | optional | Used to send the job's location is gated flag that will be set. (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) |
| `gate_instructions` | `string` | optional | Used to send the job's location gate instructions that will be set. (default: `If not passed, it takes the value from a primary location (if any) of passed customer.`) |
| `category` | `string` | optional | Used to send a category's `id` or `header` that will be attached to the job (Note: `id` - [integer] the category's identifier, `header` - [string] the category's fields concatenated by pattern `{category}`). Optionally required (configurable into the company preferences). |
| `source` | `string` | optional | Used to send a source's `id` or `header` that will be attached to the job (Note: `id` - [integer] the source's identifier, `header` - [string] the source's fields concatenated by pattern `{short_name}`). (default: `If not passed, it takes the value from the customer.`) |
| `payment_type` | `string` | optional | Used to send a payment type's `id` or `header` that will be attached to the job (Note: `id` - [integer] the payment type's identifier, `header` - [string] the payment type's fields concatenated by pattern `{short_name}`). Optionally required (configurable into the company preferences). (default: `If not passed, it takes the value from the customer.`) |
| `customer_payment_terms` | `string` | optional | Used to send a customer payment term's `id` or `header` that will be attached to the job (Note: `id` - [integer] the customer payment term's identifier, `header` - [string] the customer payment term's fields concatenated by pattern `{name}`). (default: `If not passed, it takes the value from the customer.`) |
| `project` | `string` | optional | Used to send a project's `id` or `header` that will be attached to the job (Note: `id` - [integer] the project's identifier, `header` - [string] the project's fields concatenated by pattern `{name}`). |
| `phase` | `string` | optional | Used to send a phase's `id` or `header` that will be attached to the job (Note: `id` - [integer] the phase's identifier, `header` - [string] the phase's fields concatenated by pattern `{name}`). |
| `po_number` | `string` | optional | Used to send the job's po number that will be set. |
| `contract` | `string` | optional | Used to send a contract's `id` or `header` that will be attached to the job (Note: `id` - [integer] the contract's identifier, `header` - [string] the contract's fields concatenated by pattern `{contract_title}`). (default: `If not passed, it takes the value from the customer.`) |
| `note_to_customer` | `string` | optional | Used to send the job's note to customer that will be set. (default: `If not passed, it takes the value from the company preferences.`) |
| `called_in_by` | `string` | optional | Used to send the job's called in by that will be set. |
| `is_requires_follow_up` | `boolean` | optional | Used to send the job's is requires follow up flag that will be set. (default: `false`) |
| `agents` | `array` | optional | Used to send the job's agents list that will be set. (default: `array`) |
| `custom_fields` | `array` | optional | Used to send the job's custom fields list that will be set. (default: `If some custom field (configured into the custom fields settings) not passed, it creates the new one with its default value.`) |
| `equipment` | `array` | optional | Used to send the job's equipments list that will be set. (default: `array`) |
| `techs_assigned` | `array` | optional | Used to send the job's techs assigned list that will be set. (default: `array`) |
| `tasks` | `array` | optional | Used to send the job's tasks list that will be set. (default: `array`) |
| `notes` | `array` | optional | Used to send the job's notes list that will be set. (default: `array`) |
| `products` | `array` | optional | Used to send the job's products list that will be set. (default: `array`) |
| `services` | `array` | optional | Used to send the job's services list that will be set. (default: `array`) |
| `other_charges` | `array` | optional | Used to send the job's other charges list that will be set. (default: `If not passed, it creates all entries with `auto added` option enabled. Also it creates all not passed other charges declared into `products` and `services`.`) |
| `labor_charges` | `array` | optional | Used to send the job's labor charges list that will be set. (default: `array`) |
| `expenses` | `array` | optional | Used to send the job's expenses list that will be set. (default: `array`) |

**Example:**
```json
{
  "check_number": "1877",
  "priority": "Normal",
  "description": "This is a test",
  "tech_notes": "You guys know what to do.",
  "completion_notes": "Work is done.",
  "duration": 3600,
  "time_frame_promised_start": "14:10",
  "time_frame_promised_end": "14:10",
  "start_date": "2015-01-08",
  "end_date": "2016-01-08",
  "customer_name": "Max Paltsev",
  "status": "Cancelled",
  "contact_first_name": "Sam",
  "contact_last_name": "Smith",
  "street_1": "1904 Industrial Blvd",
  "street_2": "103",
  "city": "Colleyville",
  "state_prov": "Texas",
  "postal_code": "76034",
  "location_name": "Office",
  "is_gated": false,
  "gate_instructions": null,
  "category": "Quick Home Energy Check-ups",
  "source": "Yellow Pages",
  "payment_type": "Direct Bill",
  "customer_payment_terms": "COD",
  "project": "reshma",
  "phase": "Closeup",
  "po_number": "86305",
  "contract": "Retail Service Contract",
  "note_to_customer": "Sample Note To Customer.",
  "called_in_by": "Sample Called In By",
  "is_requires_follow_up": true,
  "agents": [
    {
      "id": 31
    },
    {
      "first_name": "John",
      "last_name": "Theowner"
    }
  ],
  "custom_fields": [
    {
      "name": "Text",
      "value": "Example text value"
    },
    {
      "name": "Textarea",
      "value": "Example text area value"
    },
    {
      "name": "Date",
      "value": "2018-10-05"
    },
    {
      "name": "Numeric",
      "value": "157.25"
    },
    {
      "name": "Select",
      "value": "1 one"
    },
    {
      "name": "Checkbox",
      "value": true
    }
  ],
  "equipment": [
    {
      "id": "COIL:ABUS:LMU-2620i:445577998871",
      "type": "Test Equipment",
      "make": "New Test Manufacturer",
      "model": "TST1231MOD",
      "sku": "SK15432",
      "serial_number": "1231#SRN",
      "location": "Test Location",
      "notes": "Test notes for the Test Equipment",
      "extended_warranty_provider": "Test War Provider",
      "is_extended_warranty": false,
      "extended_warranty_date": "2015-02-17",
      "warranty_date": "2015-01-16",
      "install_date": "2014-12-15",
      "customer_location": "Office",
      "custom_fields": [
        {
          "name": "Text",
          "value": "Example text value"
        },
        {
          "name": "Textarea",
          "value": "Example text area value"
        },
        {
          "name": "Date",
          "value": "2018-10-05"
        },
        {
          "name": "Numeric",
          "value": "157.25"
        },
        {
          "name": "Select",
          "value": "1 one"
        },
        {
          "name": "Checkbox",
          "value": true
        }
      ]
    }
  ],
  "techs_assigned": [
    {
      "id": 31
    },
    {
      "first_name": "John",
      "last_name": "Theowner"
    }
  ],
  "tasks": [
    {
      "description": "x",
      "is_completed": false
    }
  ],
  "notes": [
    {
      "notes": "SHOULD BE DELIVERED TO US 6/1/15 AND RICHARD NEEDS TO PAINT"
    }
  ],
  "products": [
    {
      "name": "1755LFB-NEW",
      "description": "Finishing Trim Kit - 1\" - Black\r\nModel: \r\nSKU: \r\nType: \r\nPart Number: ",
      "multiplier": 2,
      "rate": 500,
      "cost": 100,
      "is_show_rate_items": false,
      "tax": "FIXED",
      "product": "1755LFB"
    }
  ],
  "services": [
    {
      "name": "Service Call Fee",
      "description": null,
      "multiplier": 1,
      "rate": "33.15",
      "cost": "121",
      "is_show_rate_items": true,
      "tax": "City Tax",
      "service": "Nabeeel"
    }
  ],
  "other_charges": [
    {
      "name": "fee1 new",
      "rate": "15.15",
      "is_percentage": false,
      "other_charge": "fee1"
    }
  ],
  "labor_charges": [
    {
      "drive_time_rate": "10.25",
      "drive_time_cost": "75.75",
      "drive_time_start": "10:00",
      "drive_time_end": "12:00",
      "is_drive_time_billed": false,
      "labor_time": 75,
      "labor_time_rate": "11.25",
      "labor_time_cost": "50",
      "labor_date": "2015-11-19",
      "is_labor_time_billed": true,
      "user": "Test qa"
    }
  ],
  "expenses": [
    {
      "purchased_from": "test",
      "notes": null,
      "amount": "15.25",
      "is_billable": true,
      "date": "2016-01-19",
      "user": null,
      "category": "Accounting fees"
    }
  ]
}
```

### JobView

A job's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | The job's identifier. |
| `number` | `string` | optional | The job's number. |
| `check_number` | `string` | optional | The job's check number. |
| `priority` | `string` | optional | The job's priority. |
| `description` | `string` | optional | The job's description. |
| `tech_notes` | `string` | optional | The job's tech notes. |
| `completion_notes` | `string` | optional | The job's completion notes. |
| `payment_status` | `string` | optional | The job's payment status. |
| `taxes_fees_total` | `number` | optional | The job's taxes and fees total. |
| `drive_labor_total` | `number` | optional | The job's drive and labor total. |
| `billable_expenses_total` | `number` | optional | The job's billable expenses total. |
| `total` | `number` | optional | The job's total. |
| `payments_deposits_total` | `number` | optional | The job's payments and deposits total. |
| `due_total` | `number` | optional | The job's due total. |
| `cost_total` | `number` | optional | The job's cost total. |
| `duration` | `integer` | optional | The job's duration (in seconds). |
| `time_frame_promised_start` | `string` | optional | The job's time frame promised start. |
| `time_frame_promised_end` | `string` | optional | The job's time frame promised end. |
| `start_date` | `datetime` | optional | The job's start date. |
| `end_date` | `datetime` | optional | The job's end date. |
| `created_at` | `datetime` | optional | The job's created date. |
| `updated_at` | `datetime` | optional | The job's updated date. |
| `closed_at` | `datetime` | optional | The job's closed date. |
| `customer_id` | `integer` | optional | The `id` of attached customer to the job (Note: `id` - [integer] the customer's identifier). |
| `customer_name` | `string` | optional | The `header` of attached customer to the job (Note: `header` - [string] the customer's fields concatenated by pattern `{customer_name}`). |
| `parent_customer` | `string` | optional | The `header` of attached parent customer to the job (Note: `header` - [string] the parent customer's fields concatenated by pattern `{customer_name}`). |
| `status` | `string` | optional | The `header` of attached status to the job (Note: `header` - [string] the status'es fields concatenated by pattern `{name}`). |
| `sub_status` | `string` | optional | The `header` of attached sub status to the job (Note: `header` - [string] the sub status's fields concatenated by pattern `{name}`). |
| `contact_first_name` | `string` | optional | The job's contact first name. |
| `contact_last_name` | `string` | optional | The job's contact last name. |
| `street_1` | `string` | optional | The job's location street 1. |
| `street_2` | `string` | optional | The job's location street 2. |
| `city` | `string` | optional | The job's location city. |
| `state_prov` | `string` | optional | The job's location state prov. |
| `postal_code` | `string` | optional | The job's location postal code. |
| `location_name` | `string` | optional | The job's location name. |
| `is_gated` | `boolean` | optional | The job's location is gated flag. |
| `gate_instructions` | `string` | optional | The job's location gate instructions. |
| `category` | `string` | optional | The `header` of attached category to the job (Note: `header` - [string] the category's fields concatenated by pattern `{category}`). |
| `source` | `string` | optional | The `header` of attached source to the job (Note: `header` - [string] the source's fields concatenated by pattern `{short_name}`). |
| `payment_type` | `string` | optional | The `header` of attached payment type to the job (Note: `header` - [string] the payment type's fields concatenated by pattern `{short_name}`). |
| `customer_payment_terms` | `string` | optional | The `header` of attached customer payment term to the job (Note: `header` - [string] the customer payment term's fields concatenated by pattern `{name}`). |
| `project` | `string` | optional | The `header` of attached project to the job (Note: `header` - [string] the project's fields concatenated by pattern `{name}`). |
| `phase` | `string` | optional | The `header` of attached phase to the job (Note: `header` - [string] the phase's fields concatenated by pattern `{name}`). |
| `po_number` | `string` | optional | The job's po number. |
| `contract` | `string` | optional | The `header` of attached contract to the job (Note: `header` - [string] the contract's fields concatenated by pattern `{contract_title}`). |
| `note_to_customer` | `string` | optional | The job's note to customer. |
| `called_in_by` | `string` | optional | The job's called in by. |
| `is_requires_follow_up` | `boolean` | optional | The job's is requires follow up flag. |
| `agents` | `array` | optional | The job's agents list. |
| `custom_fields` | `array` | optional | The job's custom fields list. |
| `pictures` | `array` | optional | The job's pictures list. |
| `documents` | `array` | optional | The job's documents list. |
| `equipment` | `array` | optional | The job's equipments list. |
| `techs_assigned` | `array` | optional | The job's techs assigned list. |
| `tasks` | `array` | optional | The job's tasks list. |
| `notes` | `array` | optional | The job's notes list. |
| `products` | `array` | optional | The job's products list. |
| `services` | `array` | optional | The job's services list. |
| `other_charges` | `array` | optional | The job's other charges list. |
| `labor_charges` | `array` | optional | The job's labor charges list. |
| `expenses` | `array` | optional | The job's expenses list. |
| `payments` | `array` | optional | The job's payments list. |
| `invoices` | `array` | optional | The job's invoices list. |
| `signatures` | `array` | optional | The job's signatures list. |
| `printable_work_order` | `array` | optional | The job's printable work order list. |
| `visits` | `array` | optional | The job's visits list. |
| `_expandable` | `array` | **required** | The extra-field's list that are not expanded and can be expanded into objects. |

### JobCategory

A job category's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | The job category's identifier. |
| `name` | `string` | optional | The job category's name. |

**Example:**
```json
{
  "id": 490,
  "name": "Job Category for Testing"
}
```

### JobCategoryView

A job category's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | The job category's identifier. |
| `name` | `string` | optional | The job category's name. |
| `_expandable` | `array` | **required** | The extra-field's list that are not expanded and can be expanded into objects. |

**Example:**
```json
{
  "id": 490,
  "name": "Job Category for Testing",
  "_expandable": []
}
```

### JobStatus

A job statuse's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | The job statuse's identifier. |
| `code` | `string` | optional | The job statuse's code. |
| `name` | `string` | optional | The job statuse's name. |
| `is_custom` | `string` | optional | The job statuse's is custom flag. |
| `category` | `string` | optional | The `header` of attached category to the status (Note: `header` - [string] the category's fields concatenated by pattern `{code}`). |

**Example:**
```json
{
  "id": 1018351032,
  "code": "06_ONS",
  "name": "On Site",
  "is_custom": true,
  "category": "OPEN_ACTIVE"
}
```

### JobStatusView

A job statuse's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | The job statuse's identifier. |
| `code` | `string` | optional | The job statuse's code. |
| `name` | `string` | optional | The job statuse's name. |
| `is_custom` | `string` | optional | The job statuse's is custom flag. |
| `category` | `string` | optional | The `header` of attached category to the status (Note: `header` - [string] the category's fields concatenated by pattern `{code}`). |
| `_expandable` | `array` | **required** | The extra-field's list that are not expanded and can be expanded into objects. |

**Example:**
```json
{
  "id": 1018351032,
  "code": "06_ONS",
  "name": "On Site",
  "is_custom": true,
  "category": "OPEN_ACTIVE",
  "_expandable": []
}
```

### JobDocument

A job document's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `string` | optional | The document's name. |
| `file_location` | `string` | optional | The document's file location. |
| `doc_type` | `string` | optional | The document's type. |
| `comment` | `string` | optional | The document's comment. |
| `sort` | `integer` | optional | The document's sort. |
| `is_private` | `boolean` | optional | The document's is private flag. |
| `created_at` | `datetime` | optional | The document's created date. |
| `updated_at` | `datetime` | optional | The document's updated date. |
| `customer_doc_id` | `integer` | optional | The `id` of attached customer doc to the document (Note: `id` - [integer] the customer doc's identifier). |

### JobExpense

A job expense's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `purchased_from` | `string` | optional | The expense's purchased from. |
| `notes` | `string` | optional | The expense's notes. |
| `amount` | `number` | optional | The expense's amount. |
| `is_billable` | `boolean` | optional | The expense's is billable flag. |
| `date` | `datetime` | optional | The expense's date. |
| `created_at` | `datetime` | optional | The expense's created date. |
| `updated_at` | `datetime` | optional | The expense's updated date. |
| `user` | `string` | optional | The `header` of attached user to the expense (Note: `header` - [string] the user's fields concatenated by pattern `{first_name} {last_name}` with space as separator). |
| `category` | `string` | optional | The `header` of attached category to the expense (Note: `header` - [string] the category's fields concatenated by pattern `{category_name}`). |
| `qbo_class_id` | `integer` | optional | The `id` of attached qbo class to the expense (Note: `id` - [integer] the qbo class'es identifier). |
| `qbd_class_id` | `integer` | optional | The `id` of attached qbd class to the expense (Note: `id` - [integer] the qbd class'es identifier). |

**Example:**
```json
[
  {
    "purchased_from": "test",
    "notes": null,
    "amount": 15.25,
    "is_billable": true,
    "date": "2016-01-19",
    "created_at": "2016-01-07T17:20:36+00:00",
    "updated_at": "-0001-11-30T00:00:00+00:00",
    "user": null,
    "category": "Accounting fees",
    "qbo_class_id": null,
    "qbd_class_id": null
  }
]
```

### JobExpenseBody

A job expense's body schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `purchased_from` | `string` | optional | Used to send the expense's purchased from that will be set. |
| `notes` | `string` | optional | Used to send the expense's notes that will be set. |
| `amount` | `number` | optional | Used to send the expense's amount that will be set. (default: `0`) |
| `is_billable` | `boolean` | optional | Used to send the expense's is billable flag that will be set. (default: `false`) |
| `date` | `datetime` | optional | Used to send the expense's date that will be set. |
| `user` | `string` | optional | Used to send a user's `id` or `header` that will be attached to the expense (Note: `id` - [integer] the user's identifier, `header` - [string] the user's fields concatenated by pattern `{first_name} {last_name}` with space as separator). |
| `category` | `string` | optional | Used to send a category's `id` or `header` that will be attached to the expense (Note: `id` - [integer] the category's identifier, `header` - [string] the category's fields concatenated by pattern `{category_name}`). (default: `If not passed, it takes the name of first existing category.`) |

**Example:**
```json
[
  {
    "purchased_from": "test",
    "notes": null,
    "amount": "15.25",
    "is_billable": true,
    "date": "2016-01-19",
    "user": null,
    "category": "Accounting fees"
  }
]
```

### JobLaborCharge

A job labor charge's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `drive_time` | `integer` | optional | The labor charge's drive time. |
| `drive_time_rate` | `number` | optional | The labor charge's drive time rate. |
| `drive_time_cost` | `number` | optional | The labor charge's drive time cost. |
| `drive_time_start` | `string` | optional | The labor charge's drive time start. |
| `drive_time_end` | `string` | optional | The labor charge's drive time end. |
| `is_drive_time_billed` | `boolean` | optional | The labor charge's is drive time billed flag. |
| `labor_time` | `integer` | optional | The labor charge's labor time. |
| `labor_time_rate` | `number` | optional | The labor charge's labor time rate. |
| `labor_time_cost` | `number` | optional | The labor charge's labor time cost. |
| `labor_time_start` | `string` | optional | The labor charge's labor time start. |
| `labor_time_end` | `string` | optional | The labor charge's labor time end. |
| `labor_date` | `datetime` | optional | The labor charge's labor date. |
| `is_labor_time_billed` | `boolean` | optional | The labor charge's is labor time billed flag. |
| `total` | `number` | optional | The labor charge's total. |
| `created_at` | `datetime` | optional | The labor charge's created date. |
| `updated_at` | `datetime` | optional | The labor charge's updated date. |
| `is_status_generated` | `boolean` | optional | The labor charge's is status generated flag. |
| `user` | `string` | optional | The `header` of attached user to the labor charge (Note: `header` - [string] the user's fields concatenated by pattern `{first_name} {last_name}` with space as separator). |
| `visit_id` | `integer` | optional | The `id` of attached visit to the labor charge (Note: `id` - [integer] the visit's identifier). |
| `qbo_class_id` | `integer` | optional | The `id` of attached qbo class to the labor charge (Note: `id` - [integer] the qbo class'es identifier). |
| `qbd_class_id` | `integer` | optional | The `id` of attached qbd class to the labor charge (Note: `id` - [integer] the qbd class'es identifier). |

**Example:**
```json
[
  {
    "drive_time": 0,
    "drive_time_rate": 10.25,
    "drive_time_cost": 0,
    "drive_time_start": null,
    "drive_time_end": null,
    "is_drive_time_billed": false,
    "labor_time": 0,
    "labor_time_rate": 11.25,
    "labor_time_cost": 0,
    "labor_time_start": null,
    "labor_time_end": null,
    "labor_date": "2015-11-19",
    "is_labor_time_billed": true,
    "total": 0,
    "created_at": "2015-11-19T20:38:10+00:00",
    "updated_at": "-0001-11-30T00:00:00+00:00",
    "is_status_generated": true,
    "user": "Test qa",
    "visit_id": null,
    "qbo_class_id": null,
    "qbd_class_id": null
  }
]
```

### JobLaborChargeBody

A job labor charge's body schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `drive_time` | `integer` | optional | Used to send the labor charge's drive time that will be set. Forbidden if drive times start/end passed. (default: `If drive times start/end passed, it takes the calculated difference time (in minutes), otherwise it takes the value `0`.`) |
| `drive_time_rate` | `number` | optional | Used to send the labor charge's drive time rate that will be set. (default: `0`) |
| `drive_time_cost` | `number` | optional | Used to send the labor charge's drive time cost that will be set. (default: `0`) |
| `drive_time_start` | `string` | optional | Used to send the labor charge's drive time start that will be set. Required if drive time end passed. |
| `drive_time_end` | `string` | optional | Used to send the labor charge's drive time end that will be set. Required if drive time start passed. Must be greater than drive time start. |
| `is_drive_time_billed` | `boolean` | optional | Used to send the labor charge's is drive time billed flag that will be set. (default: `false`) |
| `labor_time` | `integer` | optional | Used to send the labor charge's labor time that will be set. Forbidden if labor times start/end passed. (default: `If labor times start/end passed, it takes the calculated difference time (in minutes), otherwise it takes the value `0`.`) |
| `labor_time_rate` | `number` | optional | Used to send the labor charge's labor time rate that will be set. (default: `0`) |
| `labor_time_cost` | `number` | optional | Used to send the labor charge's labor time cost that will be set. (default: `0`) |
| `labor_time_start` | `string` | optional | Used to send the labor charge's labor time start that will be set. Required if labor time end passed. |
| `labor_time_end` | `string` | optional | Used to send the labor charge's labor time end that will be set. Required if labor time start passed. Must be greater than labor time start. |
| `labor_date` | `datetime` | optional | Used to send the labor charge's labor date that will be set. |
| `is_labor_time_billed` | `boolean` | optional | Used to send the labor charge's is labor time billed flag that will be set. (default: `false`) |
| `user` | `string` | optional | Used to send a user's `id` or `header` that will be attached to the labor charge (Note: `id` - [integer] the user's identifier, `header` - [string] the user's fields concatenated by pattern `{first_name} {last_name}` with space as separator). |

**Example:**
```json
[
  {
    "drive_time_rate": "10.25",
    "drive_time_cost": "75.75",
    "drive_time_start": "10:00",
    "drive_time_end": "12:00",
    "is_drive_time_billed": false,
    "labor_time": 75,
    "labor_time_rate": "11.25",
    "labor_time_cost": "50",
    "labor_date": "2015-11-19",
    "is_labor_time_billed": true,
    "user": "Test qa"
  }
]
```

### JobNote

A job note's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `notes` | `string` | optional | The note's text. |
| `created_at` | `datetime` | optional | The note's created date. |
| `updated_at` | `datetime` | optional | The note's updated date. |

**Example:**
```json
[
  {
    "notes": "SHOULD BE DELIVERED TO US 6/1/15 AND RICHARD NEEDS TO PAINT",
    "created_at": "2015-05-27T16:32:06+00:00",
    "updated_at": "2015-05-27T16:32:06+00:00"
  }
]
```

### JobNoteBody

A job note's body schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `notes` | `string` | **required** | Used to send the note's text that will be set. |

**Example:**
```json
[
  {
    "notes": "SHOULD BE DELIVERED TO US 6/1/15 AND RICHARD NEEDS TO PAINT"
  }
]
```

### JobOtherCharge

A job other charge's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `string` | optional | The other charge's name. |
| `rate` | `number` | optional | The other charge's rate. |
| `total` | `number` | optional | The other charge's total. |
| `charge_index` | `integer` | optional | The other charge's index. |
| `parent_index` | `integer` | optional | The other charge's parent index. |
| `is_percentage` | `boolean` | optional | The other charge's is percentage flag. |
| `is_discount` | `boolean` | optional | The other charge's is discount flag. |
| `created_at` | `datetime` | optional | The other charge's created date. |
| `updated_at` | `datetime` | optional | The other charge's updated date. |
| `other_charge` | `string` | optional | The `header` of attached other charge to the other charge (Note: `header` - [string] the other charge's fields concatenated by pattern `{short_name}`). |
| `applies_to` | `string` | optional | The other charge's applies to. |
| `service_list_id` | `integer` | optional | The `id` of attached service list to the other charge (Note: `id` - [integer] the service list's identifier). |
| `other_charge_id` | `integer` | optional | The `id` of attached other charge to the other charge (Note: `id` - [integer] the other charge's identifier). |
| `pattern_row_id` | `integer` | optional | The `id` of attached pattern row to the other charge (Note: `id` - [integer] the pattern row's identifier). |
| `qbo_class_id` | `integer` | optional | The `id` of attached qbo class to the other charge (Note: `id` - [integer] the qbo class'es identifier). |
| `qbd_class_id` | `integer` | optional | The `id` of attached qbd class to the other charge (Note: `id` - [integer] the qbd class'es identifier). |

**Example:**
```json
[
  {
    "name": "fee1",
    "rate": 5.15,
    "total": 14.3,
    "charge_index": 1,
    "parent_index": 1,
    "is_percentage": true,
    "is_discount": false,
    "created_at": "2015-08-20T09:08:52+00:00",
    "updated_at": "2015-11-19T20:38:07+00:00",
    "other_charge": "fee1",
    "applies_to": null,
    "service_list_id": null,
    "other_charge_id": 248,
    "pattern_row_id": null,
    "qbo_class_id": null,
    "qbd_class_id": null
  }
]
```

### JobOtherChargeBody

A job other charge's body schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `string` | optional | Used to send the other charge's name that will be set. (default: `If not passed, it takes the value of passed other charge.`) |
| `rate` | `number` | optional | Used to send the other charge's rate that will be set. (default: `If not passed, it takes the value of passed other charge.`) |
| `is_percentage` | `boolean` | optional | Used to send the other charge's is percentage flag that will be set. (default: `If not passed, it takes the value of passed other charge.`) |
| `other_charge` | `string` | **required** | Used to send an other charge's `id` or `header` that will be attached to the other charge (Note: `id` - [integer] the other charge's identifier, `header` - [string] the other charge's fields concatenated by pattern `{short_name}`). |

**Example:**
```json
[
  {
    "name": "fee1 new",
    "rate": "15.15",
    "is_percentage": false,
    "other_charge": "fee1"
  }
]
```

### JobProduct

A job product's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `string` | optional | The product's name. |
| `description` | `string` | optional | The product's description. |
| `multiplier` | `integer` | optional | The product's quantity. |
| `rate` | `number` | optional | The product's rate. |
| `total` | `number` | optional | The product's total. |
| `cost` | `number` | optional | The product's cost. |
| `actual_cost` | `number` | optional | The product's actual cost. |
| `item_index` | `integer` | optional | The product's item index. |
| `parent_index` | `integer` | optional | The product's parent index. |
| `created_at` | `datetime` | optional | The product's created date. |
| `updated_at` | `datetime` | optional | The product's updated date. |
| `is_show_rate_items` | `boolean` | optional | The product's is show rate items flag. |
| `tax` | `string` | optional | The `header` of attached tax to the product (Note: `header` - [string] the tax'es fields concatenated by pattern `{short_name}`). |
| `product` | `string` | optional | The `header` of attached product to the product (Note: `header` - [string] the product's fields concatenated by pattern `{make}`). |
| `product_list_id` | `integer` | optional | The `id` of attached product list to the product (Note: `id` - [integer] the product list's identifier). |
| `warehouse_id` | `integer` | optional | The `id` of attached warehouse to the product (Note: `id` - [integer] the warehouse's identifier). |
| `pattern_row_id` | `integer` | optional | The `id` of attached pattern row to the product (Note: `id` - [integer] the pattern row's identifier). |
| `qbo_class_id` | `integer` | optional | The `id` of attached qbo class to the product (Note: `id` - [integer] the qbo class'es identifier). |
| `qbd_class_id` | `integer` | optional | The `id` of attached qbd class to the product (Note: `id` - [integer] the qbd class'es identifier). |

**Example:**
```json
[
  {
    "name": "1755LFB",
    "description": "Finishing Trim Kit - 1\" - Black\r\nModel: \r\nSKU: \r\nType: \r\nPart Number: ",
    "multiplier": 3,
    "rate": 459,
    "total": 1377,
    "cost": 0,
    "actual_cost": 0,
    "item_index": 0,
    "parent_index": 0,
    "created_at": "2015-08-20T09:08:36+00:00",
    "updated_at": "2015-11-19T20:38:07+00:00",
    "is_show_rate_items": true,
    "tax": "City Tax",
    "product": "1755LFB",
    "product_list_id": 45302,
    "warehouse_id": 200,
    "pattern_row_id": null,
    "qbo_class_id": null,
    "qbd_class_id": null
  }
]
```

### JobProductBody

A job product's body schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `string` | optional | Used to send the product's name that will be set. (default: `If not passed, it takes the value of passed product.`) |
| `description` | `string` | optional | Used to send the product's description that will be set. (default: `If not passed, it takes the value of passed product.`) |
| `multiplier` | `integer` | optional | Used to send the product's quantity that will be set. (default: `If not passed, it takes the value of passed product.`) |
| `rate` | `number` | optional | Used to send the product's rate that will be set. (default: `If not passed, it takes the value of passed product.`) |
| `cost` | `number` | optional | Used to send the product's cost that will be set. (default: `If not passed, it takes the value of passed product.`) |
| `is_show_rate_items` | `boolean` | optional | Used to send the product's is show rate items flag that will be set. (default: `false`) |
| `tax` | `string` | optional | Used to send a tax'es `id` or `header` that will be attached to the product (Note: `id` - [integer] the tax'es identifier, `header` - [string] the tax'es fields concatenated by pattern `{short_name}`). |
| `product` | `string` | **required** | Used to send a product's `id` or `header` that will be attached to the product (Note: `id` - [integer] the product's identifier, `header` - [string] the product's fields concatenated by pattern `{make}`). |

**Example:**
```json
[
  {
    "name": "1755LFB-NEW",
    "description": "Finishing Trim Kit - 1\" - Black\r\nModel: \r\nSKU: \r\nType: \r\nPart Number: ",
    "multiplier": 2,
    "rate": 500,
    "cost": 100,
    "is_show_rate_items": false,
    "tax": "FIXED",
    "product": "1755LFB"
  }
]
```

### JobService

A job service's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `string` | optional | The service's name. |
| `description` | `string` | optional | The service's description. |
| `multiplier` | `integer` | optional | The service's quantity. |
| `rate` | `number` | optional | The service's rate. |
| `total` | `number` | optional | The service's total. |
| `cost` | `number` | optional | The service's cost. |
| `actual_cost` | `number` | optional | The service's actual cost. |
| `item_index` | `integer` | optional | The service's item index. |
| `parent_index` | `integer` | optional | The service's parent index. |
| `created_at` | `datetime` | optional | The service's created date. |
| `updated_at` | `datetime` | optional | The service's updated date. |
| `is_show_rate_items` | `boolean` | optional | The service's is show rate items flag. |
| `tax` | `string` | optional | The `header` of attached tax to the service (Note: `header` - [string] the tax'es fields concatenated by pattern `{short_name}`). |
| `service` | `string` | optional | The `header` of attached service to the service (Note: `header` - [string] the service's fields concatenated by pattern `{short_description}`). |
| `service_list_id` | `integer` | optional | The `id` of attached service list to the service (Note: `id` - [integer] the service list's identifier). |
| `service_rate_id` | `integer` | optional | The `id` of attached service rate to the service (Note: `id` - [integer] the service rate's identifier). |
| `pattern_row_id` | `integer` | optional | The `id` of attached pattern row to the service (Note: `id` - [integer] the pattern row's identifier). |
| `qbo_class_id` | `integer` | optional | The `id` of attached qbo class to the service (Note: `id` - [integer] the qbo class'es identifier). |
| `qbd_class_id` | `integer` | optional | The `id` of attached qbd class to the service (Note: `id` - [integer] the qbd class'es identifier). |

**Example:**
```json
[
  {
    "name": "Service Call Fee",
    "description": null,
    "multiplier": 1,
    "rate": 33.15,
    "total": 121,
    "cost": 121,
    "actual_cost": 121,
    "item_index": 3,
    "parent_index": 0,
    "created_at": "2015-08-20T09:08:36+00:00",
    "updated_at": "2015-11-19T20:38:07+00:00",
    "is_show_rate_items": true,
    "tax": "City Tax",
    "service": "Nabeeel",
    "service_list_id": 45302,
    "service_rate_id": 200,
    "pattern_row_id": null,
    "qbo_class_id": null,
    "qbd_class_id": null
  }
]
```

### JobServiceBody

A job service's body schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `string` | optional | Used to send the service's name that will be set. (default: `If not passed, it takes the value of passed service.`) |
| `description` | `string` | optional | Used to send the service's description that will be set. (default: `If not passed, it takes the value of passed service.`) |
| `multiplier` | `integer` | optional | Used to send the service's quantity that will be set. (default: `If not passed, it takes the value of passed service.`) |
| `rate` | `number` | optional | Used to send the service's rate that will be set. (default: `If not passed, it takes the value of passed service.`) |
| `cost` | `number` | optional | Used to send the service's cost that will be set. (default: `If not passed, it takes the value of passed service.`) |
| `is_show_rate_items` | `boolean` | optional | Used to send the service's is show rate items flag that will be set. (default: `false`) |
| `tax` | `string` | optional | Used to send a tax'es `id` or `header` that will be attached to the service (Note: `id` - [integer] the tax'es identifier, `header` - [string] the tax'es fields concatenated by pattern `{short_name}`). |
| `service` | `string` | **required** | Used to send a service's `id` or `header` that will be attached to the service (Note: `id` - [integer] the service's identifier, `header` - [string] the service's fields concatenated by pattern `{short_description}`). |

**Example:**
```json
[
  {
    "name": "Service Call Fee",
    "description": null,
    "multiplier": 1,
    "rate": "33.15",
    "cost": "121",
    "is_show_rate_items": true,
    "tax": "City Tax",
    "service": "Nabeeel"
  }
]
```

### JobSignature

A job signature's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | `string` | optional | The signature's type. |
| `file_name` | `string` | optional | The signature's file name. |
| `created_at` | `datetime` | optional | The signature's created date. |
| `updated_at` | `datetime` | optional | The signature's updated date. |

**Example:**
```json
[
  {
    "type": "PREWORK",
    "file_name": "https://servicefusion.s3.amazonaws.com/images/sign/139350-2015-08-25-11-35-14.png",
    "created_at": "2015-08-25T11:35:14+00:00",
    "updated_at": "2015-08-25T11:35:14+00:00"
  }
]
```

### JobTag

A job tag's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `tag` | `string` | optional | The tag's unique tag. |
| `created_at` | `datetime` | optional | The tag's created date. |
| `updated_at` | `datetime` | optional | The tag's updated date. |

**Example:**
```json
[
  {
    "tag": "Referral",
    "created_at": "2017-03-20T10:48:38+00:00",
    "updated_at": "2017-03-20T10:48:38+00:00"
  }
]
```

### JobTagBody

A job tag's body schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `tag` | `string` | **required** | Used to send the tag's unique tag that will be set. |

**Example:**
```json
[
  {
    "tag": "Referral"
  }
]
```

### JobTask

A job task's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | `string` | optional | The task's type. |
| `description` | `string` | optional | The task's description. |
| `start_time` | `string` | optional | The task's start time. |
| `start_date` | `datetime` | optional | The task's start date. |
| `end_date` | `datetime` | optional | The task's end date. |
| `is_completed` | `boolean` | optional | The task's is completed flag. |
| `created_at` | `datetime` | optional | The task's created date. |
| `updated_at` | `datetime` | optional | The task's updated date. |

**Example:**
```json
[
  {
    "type": "Misc",
    "description": "x",
    "start_time": null,
    "start_date": null,
    "end_date": null,
    "is_completed": false,
    "created_at": "2017-03-20T10:48:38+00:00",
    "updated_at": "2017-03-20T10:48:38+00:00"
  }
]
```

### JobTaskBody

A job task's body schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `description` | `string` | **required** | Used to send the task's description that will be set. |
| `is_completed` | `boolean` | optional | Used to send the task's is completed flag that will be set. (default: `false`) |

**Example:**
```json
[
  {
    "description": "x",
    "is_completed": false
  }
]
```

### JobVisit

A job visit's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `notes_for_techs` | `string` | optional | The visit's notes for techs. |
| `time_frame_promised_start` | `string` | optional | The visit's time frame promised start. |
| `time_frame_promised_end` | `string` | optional | The visit's time frame promised end. |
| `duration` | `integer` | optional | The visit's duration (in seconds). |
| `is_text_notified` | `boolean` | optional | The visit's is text notified flag. |
| `is_voice_notified` | `boolean` | optional | The visit's is voice notified flag. |
| `start_date` | `datetime` | optional | The visit's start date. |
| `techs_assigned` | `array` | optional | The visit's techs assigned list. |

**Example:**
```json
[
  {
    "notes_for_techs": "Hahahaha",
    "time_frame_promised_start": "00:00",
    "time_frame_promised_end": "00:30",
    "duration": 3600,
    "is_text_notified": false,
    "is_voice_notified": false,
    "start_date": "2018-08-21",
    "techs_assigned": [
      {
        "id": 31,
        "first_name": "Justin",
        "last_name": "Wormell",
        "status": "Started"
      },
      {
        "id": 32,
        "first_name": "John",
        "last_name": "Theowner",
        "status": "Paused"
      }
    ]
  }
]
```

### MeView

An authenticated user's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | The authenticated user's identifier. |
| `first_name` | `string` | optional | The authenticated user's first name. |
| `last_name` | `string` | optional | The authenticated user's last name. |
| `email` | `string` | optional | The authenticated user's email. |
| `_expandable` | `array` | **required** | The extra-field's list that are not expanded and can be expanded into objects. |

**Example:**
```json
{
  "id": 1472289,
  "first_name": "Justin",
  "last_name": "Wormell",
  "email": "justin@servicefusion.com",
  "_expandable": []
}
```

### Payment

A payment's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `transaction_type` | `string` | optional | The payment's transaction type. |
| `transaction_token` | `string` | optional | The payment's transaction token. |
| `transaction_id` | `string` | optional | The `id` of attached transaction to the payment (Note: `id` - [integer] the transaction's identifier). |
| `payment_transaction_id` | `integer` | optional | The `id` of attached payment transaction to the payment (Note: `id` - [integer] the payment transaction's identifier). |
| `original_transaction_id` | `integer` | optional | The `id` of attached original transaction to the payment (Note: `id` - [integer] the original transaction's identifier). |
| `apply_to` | `string` | optional | The payment's apply to. |
| `amount` | `number` | optional | The payment's amount. |
| `memo` | `string` | optional | The payment's memo. |
| `authorization_code` | `string` | optional | The payment's authorization code. |
| `bill_to_street_address` | `string` | optional | The payment's bill to street address. |
| `bill_to_postal_code` | `string` | optional | The payment's bill to postal code. |
| `bill_to_country` | `string` | optional | The payment's bill to country. |
| `reference_number` | `string` | optional | The payment's reference number. |
| `is_resync_qbo` | `boolean` | optional | The payment's is resync qbo flag. |
| `created_at` | `datetime` | optional | The payment's created date. |
| `updated_at` | `datetime` | optional | The payment's updated date. |
| `received_on` | `datetime` | optional | The payment's received date. |
| `qbo_synced_date` | `datetime` | optional | The payment's qbo synced date. |
| `qbo_id` | `integer` | optional | The `id` of attached qbo class to the payment (Note: `id` - [integer] the qbo class'es identifier). |
| `qbd_id` | `string` | optional | The `id` of attached qbd class to the payment (Note: `id` - [integer] the qbd class'es identifier). |
| `customer` | `string` | optional | The `header` of attached customer to the payment (Note: `header` - [string] the customer's fields concatenated by pattern `{customer_name}`). |
| `type` | `string` | optional | The `header` of attached customer payment method to the payment (Note: `header` - [string] the customer payment method's fields concatenated by pattern `{cc_type} {first_four} {last_four}` with space as separator). If customer payment method does not attached - it returns the `header` of attached payment type to the job payment (Note: `header` - [string] the payment type's fields concatenated by pattern `{name}`). |
| `invoice_id` | `integer` | optional | The `id` of attached invoice to the payment (Note: `id` - [integer] the invoice's identifier). |
| `gateway_id` | `integer` | optional | The `id` of attached gateway to the payment (Note: `id` - [integer] the gateway's identifier). |
| `receipt_id` | `string` | optional | The `id` of attached receipt to the payment (Note: `id` - [integer] the receipt's identifier). |

**Example:**
```json
[
  {
    "transaction_type": "AUTH_CAPTURE",
    "transaction_token": "4Tczi4OI12MeoSaC4FG2VPKj1",
    "transaction_id": "257494-0_10",
    "payment_transaction_id": 10,
    "original_transaction_id": 110,
    "apply_to": "JOB",
    "amount": 10.35,
    "memo": null,
    "authorization_code": "755972",
    "bill_to_street_address": "adddad",
    "bill_to_postal_code": "adadadd",
    "bill_to_country": null,
    "reference_number": "1976/1410",
    "is_resync_qbo": false,
    "created_at": "2015-09-25T09:56:57+00:00",
    "updated_at": "2015-09-25T09:56:57+00:00",
    "received_on": "2015-09-25T00:00:00+00:00",
    "qbo_synced_date": "2015-09-25T00:00:00+00:00",
    "qbo_id": 5,
    "qbd_id": "3792-1438659918",
    "customer": "Max Paltsev",
    "type": "Cash",
    "invoice_id": 124,
    "gateway_id": 980190963,
    "receipt_id": "ord-250915-9:56:56"
  }
]
```

### PaymentType

A payment type's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | The type's identifier. |
| `code` | `string` | optional | The type's code. |
| `short_name` | `string` | optional | The type's short name. |
| `type` | `string` | optional | The type's type. |
| `is_custom` | `boolean` | optional | The type's is custom flag. |

**Example:**
```json
{
  "id": 980190989,
  "code": "BILL",
  "short_name": "Direct Bill",
  "type": "BILL",
  "is_custom": false
}
```

### PaymentTypeView

A payment type's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | The type's identifier. |
| `code` | `string` | optional | The type's code. |
| `short_name` | `string` | optional | The type's short name. |
| `type` | `string` | optional | The type's type. |
| `is_custom` | `boolean` | optional | The type's is custom flag. |
| `_expandable` | `array` | **required** | The extra-field's list that are not expanded and can be expanded into objects. |

**Example:**
```json
{
  "id": 980190989,
  "code": "BILL",
  "short_name": "Direct Bill",
  "type": "BILL",
  "is_custom": false,
  "_expandable": []
}
```

### PrintableWorkOrder

A printable work order's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `string` | optional | The printable work order's name. |
| `url` | `string` | optional | The printable work order's url. |

**Example:**
```json
[
  {
    "name": "Print With Rates",
    "url": "https://servicefusion.com/printJobWithRates?jobId=fF7HY2Dew1E9vw2mm8FHzSOrpDrKnSl-m2WKf0Yg_Kw"
  }
]
```

### Source

A source's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | The source's identifier. |
| `short_name` | `string` | optional | The source's short name. |
| `long_name` | `string` | optional | The source's long name. |

**Example:**
```json
{
  "id": 980192647,
  "short_name": "Source for Testing",
  "long_name": "Long Description of New Testing Source"
}
```

### SourceView

A source's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | The source's identifier. |
| `short_name` | `string` | optional | The source's short name. |
| `long_name` | `string` | optional | The source's long name. |
| `_expandable` | `array` | **required** | The extra-field's list that are not expanded and can be expanded into objects. |

**Example:**
```json
{
  "id": 980192647,
  "short_name": "Source for Testing",
  "long_name": "Long Description of New Testing Source",
  "_expandable": []
}
```

### Tech

A tech's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | The tech's identifier. |
| `first_name` | `string` | optional | The tech's first name. |
| `last_name` | `string` | optional | The tech's last name. |
| `nickname_on_workorder` | `string` | optional | The tech's nickname on workorder. |
| `nickname_on_dispatch` | `string` | optional | The tech's nickname on dispatch. |
| `color_code` | `string` | optional | The tech's color code. |
| `email` | `string` | optional | The tech's email. |
| `phone_1` | `string` | optional | The tech's phone 1. |
| `phone_2` | `string` | optional | The tech's phone 2. |
| `gender` | `string` | optional | The tech's gender. |
| `department` | `string` | optional | The tech's department. |
| `title` | `string` | optional | The tech's title. |
| `bio` | `string` | optional | The tech's bio. |
| `is_phone_1_mobile` | `boolean` | optional | The tech's is phone 1 mobile flag. |
| `is_phone_1_visible_to_client` | `boolean` | optional | The tech's is phone 1 visible to client flag. |
| `is_phone_2_mobile` | `boolean` | optional | The tech's is phone 2 mobile flag. |
| `is_phone_2_visible_to_client` | `boolean` | optional | The tech's is phone 2 visible to client flag. |
| `is_sales_rep` | `boolean` | optional | The tech's is sales rep flag. |
| `is_field_worker` | `boolean` | optional | The tech's is field worker flag. |
| `created_at` | `datetime` | optional | The tech's created date. |
| `updated_at` | `datetime` | optional | The tech's updated date. |

**Example:**
```json
{
  "id": 1472289,
  "first_name": "Justin",
  "last_name": "Wormell",
  "nickname_on_workorder": "Workorder Heating",
  "nickname_on_dispatch": "Dispatch Heating",
  "color_code": "#356a9f",
  "email": "justin@servicefusion.com",
  "phone_1": "232-323-123",
  "phone_2": "444-444-4444",
  "gender": "F",
  "department": "Plumbing",
  "title": "Service Tech",
  "bio": "Here is a short bio on the tech that you can include along with your confirmations",
  "is_phone_1_mobile": false,
  "is_phone_1_visible_to_client": false,
  "is_phone_2_mobile": true,
  "is_phone_2_visible_to_client": true,
  "is_sales_rep": false,
  "is_field_worker": true,
  "created_at": "2018-08-07T18:31:28+00:00",
  "updated_at": "2018-08-07T18:31:28+00:00"
}
```

### TechView

A tech's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | `integer` | optional | The tech's identifier. |
| `first_name` | `string` | optional | The tech's first name. |
| `last_name` | `string` | optional | The tech's last name. |
| `nickname_on_workorder` | `string` | optional | The tech's nickname on workorder. |
| `nickname_on_dispatch` | `string` | optional | The tech's nickname on dispatch. |
| `color_code` | `string` | optional | The tech's color code. |
| `email` | `string` | optional | The tech's email. |
| `phone_1` | `string` | optional | The tech's phone 1. |
| `phone_2` | `string` | optional | The tech's phone 2. |
| `gender` | `string` | optional | The tech's gender. |
| `department` | `string` | optional | The tech's department. |
| `title` | `string` | optional | The tech's title. |
| `bio` | `string` | optional | The tech's bio. |
| `is_phone_1_mobile` | `boolean` | optional | The tech's is phone 1 mobile flag. |
| `is_phone_1_visible_to_client` | `boolean` | optional | The tech's is phone 1 visible to client flag. |
| `is_phone_2_mobile` | `boolean` | optional | The tech's is phone 2 mobile flag. |
| `is_phone_2_visible_to_client` | `boolean` | optional | The tech's is phone 2 visible to client flag. |
| `is_sales_rep` | `boolean` | optional | The tech's is sales rep flag. |
| `is_field_worker` | `boolean` | optional | The tech's is field worker flag. |
| `created_at` | `datetime` | optional | The tech's created date. |
| `updated_at` | `datetime` | optional | The tech's updated date. |
| `_expandable` | `array` | **required** | The extra-field's list that are not expanded and can be expanded into objects. |

**Example:**
```json
{
  "id": 1472289,
  "first_name": "Justin",
  "last_name": "Wormell",
  "nickname_on_workorder": "Workorder Heating",
  "nickname_on_dispatch": "Dispatch Heating",
  "color_code": "#356a9f",
  "email": "justin@servicefusion.com",
  "phone_1": "232-323-123",
  "phone_2": "444-444-4444",
  "gender": "F",
  "department": "Plumbing",
  "title": "Service Tech",
  "bio": "Here is a short bio on the tech that you can include along with your confirmations",
  "is_phone_1_mobile": false,
  "is_phone_1_visible_to_client": false,
  "is_phone_2_mobile": true,
  "is_phone_2_visible_to_client": true,
  "is_sales_rep": false,
  "is_field_worker": true,
  "created_at": "2018-08-07T18:31:28+00:00",
  "updated_at": "2018-08-07T18:31:28+00:00",
  "_expandable": []
}
```

### Picture

A picture's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `string` | optional | The document's name. |
| `file_location` | `string` | optional | The document's file location. |
| `doc_type` | `string` | optional | The document's type. |
| `comment` | `string` | optional | The document's comment. |
| `sort` | `integer` | optional | The document's sort. |
| `is_private` | `boolean` | optional | The document's is private flag. |
| `created_at` | `datetime` | optional | The document's created date. |
| `updated_at` | `datetime` | optional | The document's updated date. |
| `customer_doc_id` | `integer` | optional | The `id` of attached customer doc to the document (Note: `id` - [integer] the customer doc's identifier). |

**Example:**
```json
[
  {
    "name": "1442951633_images.jpeg",
    "file_location": "1442951633_images.jpeg",
    "doc_type": "IMG",
    "comment": null,
    "sort": 2,
    "is_private": false,
    "created_at": "2015-09-22T19:53:53+00:00",
    "updated_at": "2015-09-22T19:53:53+00:00",
    "customer_doc_id": 992
  }
]
```

### Document

A document's schema.

**Base type:** `object`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `string` | optional | The document's name. |
| `file_location` | `string` | optional | The document's file location. |
| `doc_type` | `string` | optional | The document's type. |
| `comment` | `string` | optional | The document's comment. |
| `sort` | `integer` | optional | The document's sort. |
| `is_private` | `boolean` | optional | The document's is private flag. |
| `created_at` | `datetime` | optional | The document's created date. |
| `updated_at` | `datetime` | optional | The document's updated date. |
| `customer_doc_id` | `integer` | optional | The `id` of attached customer doc to the document (Note: `id` - [integer] the customer doc's identifier). |

**Example:**
```json
[
  {
    "name": "test1John.pdf",
    "file_location": "1421408539_test1John.pdf",
    "doc_type": "DOC",
    "comment": null,
    "sort": 1,
    "is_private": false,
    "created_at": "2015-01-16T11:42:19+00:00",
    "updated_at": "2018-08-21T08:21:14+00:00",
    "customer_doc_id": 998
  }
]
```
